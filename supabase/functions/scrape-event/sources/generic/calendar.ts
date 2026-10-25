import { Document, elements } from "./dom.ts";
import {
  absoluteUrl,
  Candidate,
  decodeEntities,
  plainText,
} from "./normalize.ts";
import { isValidTimezone } from "../lib/time.ts";

export type FetchCalendar = (url: URL) => Promise<string>;

/** Every link target on the page, resolved to absolute URLs */
function pageLinks(doc: Document, pageUrl: URL): URL[] {
  const links: URL[] = [];
  for (const element of elements(doc, "a[href], link[href]")) {
    const href = element.getAttribute("href")!;
    try {
      const url = new URL(
        decodeEntities(href.trim()).replace(/^webcals?:/i, "https:"),
        pageUrl,
      );
      if (element.getAttribute("type") == "text/calendar") {
        url.hash = "text/calendar";
      }
      links.push(url);
    } catch (_e) {
      // ignore unparseable hrefs
    }
  }

  // buttons that navigate to a calendar file from script
  for (const element of elements(doc, "[onclick], [data-href], [data-url]")) {
    const attrs = ["onclick", "data-href", "data-url"]
      .map((name) => element.getAttribute(name) ?? "")
      .join(" ");
    for (const [, href] of attrs.matchAll(SCRIPTED_ICS_URL)) {
      try {
        links.push(new URL(decodeEntities(href), pageUrl));
      } catch (_e) {
        // ignore unparseable hrefs
      }
    }
  }

  return links;
}

const SCRIPTED_ICS_URL = /['"]?([^'"\s]+\.ics(?:\?[^'"\s]*)?)['"]?/gi;

/** Use a value only if every source agrees on it; listing pages carry many
 * different events, and picking one at random would be worse than none */
function onlyOne<T>(items: T[], key: (item: T) => string): T | undefined {
  const keys = new Set(items.map(key));
  return keys.size == 1 ? items[0] : undefined;
}

/** "20261114T190000Z" or "20261114" → ISO "2026-11-14T19:00:00Z" / "2026-11-14" */
function compactDateToIso(value: string | null): string | undefined {
  const match = value?.trim().match(
    /^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?$/i,
  );
  if (!match) return value?.trim() || undefined;
  const [, y, m, d, hh, mm, ss, z] = match;
  return hh
    ? `${y}-${m}-${d}T${hh}:${mm}:${ss ?? "00"}${z ? "Z" : ""}`
    : `${y}-${m}-${d}`;
}

/** Read an "add to calendar" link for Google, Outlook, or Yahoo */
function parseCalendarLink(url: URL): Candidate | undefined {
  const params = url.searchParams;
  const host = url.hostname;

  if (
    (host == "calendar.google.com" || host.endsWith("google.com")) &&
    /calendar/.test(url.pathname) && params.get("action") == "TEMPLATE"
  ) {
    const [start, end] = (params.get("dates") ?? "").split("/");
    const ctz = params.get("ctz") ?? undefined;
    return {
      title: plainText(params.get("text")),
      description: plainText(params.get("details")),
      start: compactDateToIso(start),
      end: compactDateToIso(end),
      location: plainText(params.get("location")),
      timezone: isValidTimezone(ctz) ? ctz : undefined,
    };
  }

  if (
    /^outlook\.(live|office|office365)\.com$/.test(host) &&
    /deeplink\/compose/.test(url.pathname)
  ) {
    return {
      title: plainText(params.get("subject")),
      description: plainText(params.get("body")),
      start: params.get("startdt") ?? undefined,
      end: params.get("enddt") ?? undefined,
      location: plainText(params.get("location")),
    };
  }

  if (host == "calendar.yahoo.com") {
    return {
      title: plainText(params.get("title")),
      description: plainText(params.get("desc")),
      start: compactDateToIso(params.get("st")),
      end: compactDateToIso(params.get("et")),
      location: plainText(params.get("in_loc")),
    };
  }

  return undefined;
}

function isIcsLink(url: URL): boolean {
  return /\.ics$/i.test(url.pathname) ||
    url.hash == "#text/calendar" ||
    url.searchParams.get("ical") == "1" ||
    url.searchParams.has("outlook-ical");
}

// node-ical values may be plain strings or {params, val} objects
// deno-lint-ignore no-explicit-any
function icalValue(value: any): string | undefined {
  return typeof value == "object" && value != null ? value.val : value;
}

// node-ical marks all-day dates with a dateOnly flag on the Date
function icalDate(
  value: (Date & { dateOnly?: boolean }) | undefined,
): string | Date | undefined {
  if (!(value instanceof Date)) return undefined;
  if (!value.dateOnly) return value;

  // date-only values are built at local midnight; keep just the date
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${value.getFullYear()}-${pad(value.getMonth() + 1)}-${
    pad(value.getDate())
  }`;
}

/** Parse an iCal file and pick the VEVENT for this page */
export async function parseIcs(
  ics: string,
  pageUrl: URL,
): Promise<Candidate | undefined> {
  const ical = await import("npm:node-ical");
  const entries = Object.values(ical.sync.parseICS(ics))
    // deno-lint-ignore no-explicit-any
    .filter((entry: any) => entry.type == "VEVENT");

  // deno-lint-ignore no-explicit-any
  const matching = entries.filter((entry: any) => {
    const url = absoluteUrl(icalValue(entry.url), pageUrl);
    return url && new URL(url).pathname == pageUrl.pathname;
  });
  // deno-lint-ignore no-explicit-any
  const event: any = matching[0] ??
    (entries.length == 1 ? entries[0] : undefined);
  if (!event) return undefined;

  const tz = event.start?.tz;
  return {
    title: plainText(icalValue(event.summary)),
    description: plainText(icalValue(event.description)),
    start: icalDate(event.start),
    end: icalDate(event.end),
    location: plainText(icalValue(event.location)),
    lat: event.geo?.lat,
    lon: event.geo?.lon,
    timezone: isValidTimezone(tz) ? tz : undefined,
  };
}

/** Read event details from "add to calendar" links and .ics downloads */
export async function extractCalendar(
  doc: Document,
  pageUrl: URL,
  fetchCalendar: FetchCalendar,
): Promise<Candidate | undefined> {
  const links = pageLinks(doc, pageUrl);

  // an .ics file carries real timezone info, so prefer it when there is one.
  // parseIcs only accepts a single-event file or the entry for this page, so
  // whole-venue feeds linked from the page are skipped
  const icsLinks = [
    ...new Set(
      links.filter(isIcsLink).map((url) => url.href.replace(/#.*$/, "")),
    ),
  ];
  for (const icsLink of icsLinks.slice(0, 2)) {
    try {
      const candidate = await parseIcs(
        await fetchCalendar(new URL(icsLink)),
        pageUrl,
      );
      if (candidate?.start) return candidate;
    } catch (e) {
      console.log(`Failed to load calendar file ${icsLink}: ${e}`);
    }
  }

  const fromLinks = links
    .map(parseCalendarLink)
    .filter((candidate): candidate is Candidate => !!candidate?.start);
  return onlyOne(fromLinks, (candidate) => String(candidate.start));
}
