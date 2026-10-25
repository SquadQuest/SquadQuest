/**
 * Capture a real event page as a regression case for wild_test.ts.
 *
 *   deno run -A --unstable-temporal --env=supabase/functions/.env \
 *     supabase/functions/scrape-event/sources/generic/fixtures/capture.ts \
 *     <slug> <url> [--html=saved.html] [--timezone=America/New_York]
 *
 *   ... capture.ts --rebaseline <slug>...   (after an intended change)
 *
 * Saves a trimmed copy of the page (scripts other than JSON-LD, styles, and
 * presentational attributes removed) plus everything extraction fetched along
 * the way — calendar files, timezone lookups, and the LLM's answer — so the
 * test replays offline. The current result is recorded as the expected
 * snapshot: review it before committing.
 */
import { DOMParser, Element, elements } from "../dom.ts";
import { extractFromHtml } from "../index.ts";
import { fetchPage, fetchText, isBlockedPage } from "../fetch-page.ts";
import { extractFromText, LlmResult } from "../llm.ts";
import { lookupTimezoneByGeo } from "../../lib/time.ts";
import { Event } from "../../../../_shared/squadquest.ts";

export const WILD_DIR = new URL("./wild/", import.meta.url);

export interface WildCase {
  url: string;
  captured_at: string;
  timezone: string;
  /** What a person reading the page would conclude, for reference */
  page_shows?: unknown;
  notes?: string;
  replay: {
    calendars: Record<string, string>;
    timezones: Record<string, string | null>;
    llm: LlmResult | null;
  };
  expected: Snapshot;
}

export type Snapshot =
  | { blocked: true }
  | { error: string }
  | Record<string, string | undefined>;

/** The comparable parts of an extracted event */
export function snapshot(event: Event): Snapshot {
  // round-trip through JSON so missing fields compare like saved ones
  return JSON.parse(JSON.stringify({
    title: event.title,
    start_time_min: event.start_time_min?.toISOString(),
    start_time_max: event.start_time_max?.toISOString(),
    end_time: event.end_time?.toISOString(),
    location_description: event.location_description,
    rally_point_text: event.rally_point_text,
    banner_photo: event.banner_photo,
    notes: event.notes,
  }));
}

const KEEP_SCRIPT_TYPES = new Set(["application/ld+json"]);
const DROP_ELEMENTS =
  "style, svg, iframe, canvas, video, audio, picture source";
const KEEP_LINK_RELS = /canonical|alternate/i;
const DROP_ATTRIBUTES =
  /^(style|class|srcset|sizes|loading|decoding|aria-.*|data-(?!href$|url$).*|on(?!click$).*)$/i;

/** Strip a page down to what extraction reads, keeping it small enough to commit */
export function trimHtml(html: string): string {
  // challenge pages are tiny and detected by their scripts, so keep them whole
  if (isBlockedPage(html) || html.length < 20_000) return html;

  const doc = new DOMParser().parseFromString(html, "text/html")!;

  for (const script of elements(doc, "script")) {
    const type = script.getAttribute("type")?.trim().toLowerCase() ?? "";
    if (!KEEP_SCRIPT_TYPES.has(type)) script.remove();
  }
  for (const element of elements(doc, DROP_ELEMENTS)) element.remove();
  for (const link of elements(doc, "link")) {
    const keep = KEEP_LINK_RELS.test(link.getAttribute("rel") ?? "") ||
      link.getAttribute("type") == "text/calendar";
    if (!keep) link.remove();
  }
  for (const element of elements(doc, "*")) {
    for (const name of element.getAttributeNames()) {
      if (DROP_ATTRIBUTES.test(name)) element.removeAttribute(name);
    }
  }

  const root = doc.documentElement as Element;
  return `<!doctype html>\n${root.outerHTML.replace(/<!--[\s\S]*?-->/g, "")}\n`;
}

/** Run extraction against a captured case, replaying its recorded fetches */
export async function replay(html: string, wild: WildCase): Promise<Snapshot> {
  if (isBlockedPage(html)) return { blocked: true };
  try {
    const event = await extractFromHtml(html, new URL(wild.url), {
      timezone: wild.timezone,
      now: new Date(wild.captured_at),
      fetchCalendar: (url) => {
        const ics = wild.replay.calendars[url.href];
        return ics != null
          ? Promise.resolve(ics)
          : Promise.reject(new Error(`no recorded calendar for ${url}`));
      },
      lookupTimezone: (lat, lon) =>
        Promise.resolve(wild.replay.timezones[`${lat},${lon}`] ?? null),
      llm: wild.replay.llm ? () => Promise.resolve(wild.replay.llm!) : null,
    });
    return snapshot(event);
  } catch (error) {
    return { error: (error as Error).message };
  }
}

export async function capture(
  slug: string,
  url: string,
  options: {
    html?: string;
    timezone?: string;
    pageShows?: unknown;
    notes?: string;
  } = {},
): Promise<WildCase> {
  const html = options.html ?? (await fetchPage(new URL(url))).text;
  const wild: WildCase = {
    url,
    captured_at: new Date().toISOString(),
    timezone: options.timezone ?? "America/New_York",
    page_shows: options.pageShows,
    notes: options.notes,
    replay: { calendars: {}, timezones: {}, llm: null },
    expected: { error: "not captured" },
  };

  // run once for real, recording every outside call
  const useLlm = !!Deno.env.get("ANTHROPIC_API_KEY");
  if (!isBlockedPage(html)) {
    try {
      await extractFromHtml(html, new URL(url), {
        timezone: wild.timezone,
        now: new Date(wild.captured_at),
        fetchCalendar: async (calendarUrl) => {
          const { text } = await fetchText(
            calendarUrl,
            "text/calendar,*/*;q=0.5",
          );
          wild.replay.calendars[calendarUrl.href] = text;
          return text;
        },
        lookupTimezone: async (lat, lon) => {
          const timezone = await lookupTimezoneByGeo(lat, lon);
          wild.replay.timezones[`${lat},${lon}`] = timezone;
          return timezone;
        },
        llm: useLlm
          ? async (text, hints, today) => {
            const result = await extractFromText(text, hints, today);
            // topics depend on the database, so don't record them
            wild.replay.llm = { extracted: result.extracted };
            return result;
          }
          : null,
      });
    } catch (_error) {
      // failures are part of the snapshot below
    }
  }

  const trimmed = trimHtml(html);
  wild.expected = await replay(trimmed, wild);

  // the trimmed page must behave exactly like the original
  const original = await replay(html, wild);
  if (JSON.stringify(original) != JSON.stringify(wild.expected)) {
    throw new Error(
      `Trimmed page extracts differently for ${slug}:\n` +
        `${JSON.stringify(original)}\n${JSON.stringify(wild.expected)}`,
    );
  }

  await Deno.mkdir(WILD_DIR, { recursive: true });
  await Deno.writeTextFile(new URL(`${slug}.html`, WILD_DIR), trimmed);
  await Deno.writeTextFile(
    new URL(`${slug}.json`, WILD_DIR),
    JSON.stringify(wild, null, 2) + "\n",
  );
  return wild;
}

/** Recompute a case's expected result from its recorded data, after an
 * intended behavior change, without refetching anything */
export async function rebaseline(slug: string): Promise<Snapshot> {
  const file = new URL(`${slug}.json`, WILD_DIR);
  const wild: WildCase = JSON.parse(await Deno.readTextFile(file));
  const html = await Deno.readTextFile(new URL(`${slug}.html`, WILD_DIR));
  wild.expected = await replay(html, wild);
  await Deno.writeTextFile(file, JSON.stringify(wild, null, 2) + "\n");
  return wild.expected;
}

if (import.meta.main && Deno.args[0] == "--rebaseline") {
  for (const slug of Deno.args.slice(1)) {
    console.log(slug, JSON.stringify(await rebaseline(slug), null, 2));
  }
} else if (import.meta.main) {
  const [slug, url] = Deno.args.filter((arg) => !arg.startsWith("--"));
  const flag = (name: string) =>
    Deno.args.find((arg) => arg.startsWith(`--${name}=`))?.split("=")
      .slice(1).join("=");

  if (!slug || !url) {
    console.error(
      "usage: capture.ts <slug> <url> [--html=file] [--timezone=tz]",
    );
    Deno.exit(1);
  }

  const htmlFile = flag("html");
  const wild = await capture(slug, url, {
    html: htmlFile ? await Deno.readTextFile(htmlFile) : undefined,
    timezone: flag("timezone"),
  });
  console.log(JSON.stringify(wild.expected, null, 2));
}
