import { Document, elements } from "./dom.ts";
import {
  Candidate,
  eventNodeToCandidate,
  isEventType,
  JsonValue,
  plainText,
  text,
  typeNames,
} from "./normalize.ts";
import { parseTimeValue } from "../lib/time.ts";

/** How long after it starts an event still counts as upcoming */
const UPCOMING_GRACE_MS = 12 * 60 * 60 * 1000;

/** A rough timestamp for ranking events, reading wall times as UTC */
function approximateTime(value: string | undefined): number | undefined {
  const parsed = parseTimeValue(value);
  if (!parsed) return undefined;
  if ("instant" in parsed) return parsed.instant.getTime();
  const { year, month, day, hour = 12, minute = 0 } = parsed.local;
  return Date.UTC(year, month - 1, day, hour, minute);
}

/** Parse a JSON-LD block, retrying with common real-world breakage cleaned up:
 * HTML comment / CDATA wrappers, raw control characters inside strings, and
 * trailing commas. Returns undefined if it still won't parse. */
export function parseJsonLenient(raw: string): JsonValue {
  const trimmed = raw.trim();
  if (!trimmed) return undefined;

  try {
    return JSON.parse(trimmed);
  } catch (_e) {
    // fall through to cleanup
  }

  const cleaned = trimmed
    .replace(/^\s*(?:\/\/\s*)?(?:<!--|<!\[CDATA\[)/, "")
    .replace(/(?:\/\/\s*)?(?:-->|\]\]>)\s*$/, "")
    // deno-lint-ignore no-control-regex
    .replace(/[\u0000-\u001f]+/g, " ")
    .replace(/,\s*([}\]])/g, "$1");

  try {
    return JSON.parse(cleaned);
  } catch (_e) {
    return undefined;
  }
}

/** Flatten every object in a JSON-LD value — top level, arrays, @graph, and
 * nested properties like mainEntity or subEvent — into one list */
function collectNodes(
  value: JsonValue,
  nodes: JsonValue[],
  depth = 0,
): void {
  if (value == null || typeof value != "object" || depth > 12) return;

  if (Array.isArray(value)) {
    for (const item of value) collectNodes(item, nodes, depth + 1);
    return;
  }

  nodes.push(value);
  for (const child of Object.values(value)) {
    collectNodes(child, nodes, depth + 1);
  }
}

function sameUrl(a: string | undefined, b: URL): boolean {
  if (!a) return false;
  try {
    const url = new URL(a, b);
    const strip = (u: URL) =>
      `${u.hostname.replace(/^www\./, "")}${u.pathname.replace(/\/$/, "")}`;
    return strip(url) == strip(b);
  } catch (_e) {
    return false;
  }
}

/** Find the page's main schema.org Event in its JSON-LD blocks */
export function extractJsonLd(
  doc: Document,
  pageUrl: URL,
  now: Date = new Date(),
): Candidate | undefined {
  const nodes: JsonValue[] = [];

  for (const script of elements(doc, "script")) {
    const type = script.getAttribute("type")?.trim().toLowerCase();
    if (type != "application/ld+json") continue;
    collectNodes(parseJsonLenient(script.textContent), nodes);
  }

  // index nodes by @id so references like {"@id": "#venue"} can be followed
  const byId = new Map<string, JsonValue>();
  for (const node of nodes) {
    const id = node["@id"];
    if (
      typeof id == "string" && Object.keys(node).length > 1 && !byId.has(id)
    ) {
      byId.set(id, node);
    }
  }
  const deref = (value: JsonValue): JsonValue => {
    if (
      value && typeof value == "object" && !Array.isArray(value) &&
      typeof value["@id"] == "string" &&
      Object.keys(value).every((key) => key == "@id" || key == "@type")
    ) {
      return byId.get(value["@id"]) ?? value;
    }
    return value;
  };

  const events = nodes
    .map(deref)
    .filter((node) => typeNames(node).some(isEventType));

  if (!events.length) return undefined;

  // Prefer the event this page is about, then one that hasn't happened yet:
  // recurring events list every instance, and sidebars list other events.
  // Among equals, the soonest upcoming (or else the first listed) wins.
  const upcomingAfter = now.getTime() - UPCOMING_GRACE_MS;
  const ranked = events.map((event, index) => {
    const start = approximateTime(text(event.startDate));
    return {
      event,
      index,
      start,
      score: (sameUrl(text(event.url), pageUrl) ? 8 : 0) +
        (start != null && start >= upcomingAfter ? 4 : 0) +
        (start != null ? 2 : 0) +
        (plainText(event.name) ? 1 : 0),
    };
  });
  ranked.sort((a, b) =>
    b.score - a.score ||
    (a.start != null && b.start != null && a.start >= upcomingAfter &&
        b.start >= upcomingAfter
      ? a.start - b.start
      : a.index - b.index)
  );
  const best = ranked[0].event;

  return eventNodeToCandidate(best, pageUrl, deref);
}
