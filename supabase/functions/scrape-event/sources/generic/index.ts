import { assert } from "../../../_shared/http.ts";
import { Event, EventVisibility } from "../../../_shared/squadquest.ts";
import { ScrapeContext } from "../types.ts";
import {
  currentDateInZone,
  isValidTimezone,
  lookupTimezoneByGeo,
  ParsedTime,
  parseTimeValue,
  wallTimeToUtc,
} from "../lib/time.ts";
import { extractCalendar, FetchCalendar } from "./calendar.ts";
import { DOMParser } from "./dom.ts";
import { fetchPage, fetchText } from "./fetch-page.ts";
import { extractJsonLd } from "./json-ld.ts";
import {
  ExtractFromText,
  extractFromText,
  LlmResult,
  pageText,
} from "./llm.ts";
import { extractMeta, siteName } from "./meta.ts";
import { extractMicrodata } from "./microdata.ts";
import { Candidate, mergeCandidates, stripSiteName } from "./normalize.ts";

export interface ExtractOptions {
  /** The importing device's IANA timezone, for times given without an offset */
  timezone?: string;
  lookupTimezone?: (lat: number, lon: number) => Promise<string | null>;
  fetchCalendar?: FetchCalendar;
  /** Text extraction model; null disables the LLM stage */
  llm?: ExtractFromText | null;
  /** The current time, for telling upcoming events from past ones */
  now?: Date;
}

const DEFAULT_START_WINDOW_MS = 15 * 60 * 1000;

/** Below this much readable text, a page is an app shell or error page */
const MIN_TEXT_LENGTH = 200;

const defaultFetchCalendar: FetchCalendar = async (url) =>
  (await fetchText(url, "text/calendar,*/*;q=0.5")).text;

function defaultLlm(): ExtractFromText | null {
  return Deno.env.get("ANTHROPIC_API_KEY") ? extractFromText : null;
}

function hasTime(parsed: ParsedTime | undefined): boolean {
  return !!parsed && ("instant" in parsed || parsed.local.hour != null);
}

/** The model answers 00:00 when a page shows a date but no time, so read
 * midnight as "no time given" */
function withoutMidnight(
  parsed: ParsedTime | undefined,
): ParsedTime | undefined {
  if (
    parsed && "local" in parsed && parsed.local.hour == 0 &&
    !parsed.local.minute
  ) {
    return { local: { ...parsed.local, hour: undefined, minute: undefined } };
  }
  return parsed;
}

/** Whether a date-only value falls before today ("YYYY-MM-DD") */
function isPastDay(parsed: ParsedTime, today: string): boolean {
  if (!("local" in parsed)) return false;
  const { year, month, day } = parsed.local;
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${year}-${pad(month)}-${pad(day)}` < today;
}

function sameDay(a: ParsedTime | undefined, b: ParsedTime | undefined) {
  return !!a && !!b && "local" in a && "local" in b &&
    a.local.year == b.local.year && a.local.month == b.local.month &&
    a.local.day == b.local.day;
}

/** Summarize what the metadata found, to anchor the LLM */
function llmHints(candidate: Candidate): Record<string, string> {
  const hints: Record<string, string> = {};
  if (candidate.title) hints.title = candidate.title;
  if (candidate.start) hints.start = String(candidate.start);
  if (candidate.end) hints.end = String(candidate.end);
  if (candidate.location) hints.location = candidate.location;
  return hints;
}

/** Extract an event from a page's HTML using every metadata source available,
 * falling back to reading the page text with an LLM for anything missing */
export async function extractFromHtml(
  html: string,
  pageUrl: URL,
  options: ExtractOptions = {},
): Promise<Event> {
  const {
    lookupTimezone = lookupTimezoneByGeo,
    fetchCalendar = defaultFetchCalendar,
    llm = defaultLlm(),
    now = new Date(),
  } = options;

  const doc = new DOMParser().parseFromString(html, "text/html");
  assert(!!doc, "Failed to parse page");

  // structured sources first, from most to least specific
  const structured = [
    extractJsonLd(doc!, pageUrl, now),
    extractMicrodata(doc!, pageUrl),
    await extractCalendar(doc!, pageUrl, fetchCalendar),
  ];
  const candidate = mergeCandidates([
    ...structured,
    extractMeta(doc!, pageUrl),
  ]);
  // page titles often carry site names and taglines that event names don't
  const titleFromMeta = !structured.some((source) => source?.title);

  // timezone for wall times: the source's own, then the venue's, then the device's
  let timezone = candidate.timezone;
  if (!timezone && candidate.lat != null && candidate.lon != null) {
    timezone = (await lookupTimezone(candidate.lat, candidate.lon)) ??
      undefined;
  }
  if (!timezone && isValidTimezone(options.timezone)) {
    timezone = options.timezone;
  }
  if (!timezone) {
    console.log("No timezone found for event, assuming UTC");
    timezone = "UTC";
  }

  candidate.title = stripSiteName(candidate.title, siteName(doc!));

  let start = parseTimeValue(candidate.start);
  let startMax: ParsedTime | undefined;
  let end = parseTimeValue(candidate.end);
  const today = currentDateInZone(timezone, now);

  // read the page text when metadata is missing the start time or title
  const text = pageText(doc!);
  let llmResult: LlmResult | undefined;
  if (
    llm && text.length >= MIN_TEXT_LENGTH &&
    (!hasTime(start) || !candidate.title)
  ) {
    try {
      llmResult = await llm(text, llmHints(candidate), today);
    } catch (e) {
      console.error("LLM page extraction failed:", e);
    }
  }

  const extracted = llmResult?.extracted;
  if (extracted?.is_event && !hasTime(start)) {
    const llmStart = withoutMidnight(
      parseTimeValue(extracted.start_date_local),
    );
    // trust the model's time for the date the metadata gave, if any; a past
    // date-only start is usually a long run's opening night, not a performance
    if (
      llmStart && (!start || (hasTime(llmStart) &&
        (sameDay(start, llmStart) || isPastDay(start, today))))
    ) {
      if (start && !sameDay(start, llmStart)) end = undefined;
      start = llmStart;
      startMax = parseTimeValue(extracted.start_max_local);
      end ??= parseTimeValue(extracted.end_date_local);
    }
  }

  assert(
    !!start || extracted?.is_event !== false,
    "This page doesn't appear to describe a single event",
    404,
  );
  assert(
    !!start || text.length >= MIN_TEXT_LENGTH,
    "This page loads its details with JavaScript or a login, which import can't read. Try entering the event manually",
  );

  const toDate = (parsed: ParsedTime | undefined): Date | undefined =>
    !parsed
      ? undefined
      : "instant" in parsed
      ? parsed.instant
      : wallTimeToUtc(parsed.local, timezone!);

  // a date with no time anywhere on the page lands at midday, so the day is
  // right and the person importing it adjusts the time
  const startTime = toDate(start);
  assert(
    startTime != null,
    "Could not find the event's date and time on this page",
  );

  const startTimeMax = toDate(startMax);
  const endTime = hasTime(end) ? toDate(end) : undefined;

  return {
    title: (titleFromMeta && extracted?.is_event && extracted.title) ||
      candidate.title || extracted?.title || undefined,
    start_time_min: startTime,
    start_time_max: startTimeMax && startTimeMax > startTime!
      ? startTimeMax
      : new Date(startTime!.getTime() + DEFAULT_START_WINDOW_MS),
    end_time: endTime && endTime > startTime! ? endTime : undefined,
    location_description: candidate.location ??
      extracted?.location_description ?? undefined,
    rally_point_text: candidate.lat != null && candidate.lon != null
      ? `POINT(${candidate.lon} ${candidate.lat})`
      : undefined,
    link: pageUrl.toString(),
    notes: candidate.description ?? extracted?.notes ?? undefined,
    banner_photo: candidate.image,
    topic: llmResult?.topic,
    visibility: EventVisibility.public,
  };
}

function canScrape(_url: URL): boolean {
  // This is a fallback scraper, so we'll try it on any URL
  return true;
}

async function scrape(url: URL, context: ScrapeContext): Promise<Event> {
  const page = await fetchPage(url);
  const event = await extractFromHtml(page.text, page.url, {
    timezone: context.timezone,
  });
  // keep the link the person shared rather than wherever it redirected
  return { ...event, link: url.toString() };
}

export default { canScrape, scrape };
