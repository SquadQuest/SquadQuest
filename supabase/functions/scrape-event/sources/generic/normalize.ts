/** Raw-ish event fields gathered from one metadata source on a page. Times
 * stay unparsed (or as absolute Dates) until all sources have been merged. */
export interface Candidate {
  title?: string;
  description?: string;
  start?: string | Date;
  end?: string | Date;
  location?: string;
  lat?: number;
  lon?: number;
  image?: string;
  /** IANA timezone stated by the source itself (e.g. an iCal TZID) */
  timezone?: string;
}

// deno-lint-ignore no-explicit-any
export type JsonValue = any;

/** Resolves a JSON-LD {"@id": ...} reference to the full node, if known */
export type Deref = (value: JsonValue) => JsonValue;

const identity: Deref = (value) => value;

/** Merge candidates field by field; earlier candidates take priority */
export function mergeCandidates(
  candidates: Array<Candidate | undefined>,
): Candidate {
  const merged: Candidate = {};
  for (const candidate of candidates) {
    if (!candidate) continue;
    for (const [key, value] of Object.entries(candidate)) {
      const field = key as keyof Candidate;
      if (merged[field] == null && value != null && value !== "") {
        // deno-lint-ignore no-explicit-any
        (merged as any)[field] = value;
      }
    }
  }

  // coordinates only make sense as a pair from the same source
  if (merged.lat == null || merged.lon == null) {
    delete merged.lat;
    delete merged.lon;
  }

  return merged;
}

const NAMED_ENTITIES: Record<string, string> = {
  amp: "&",
  lt: "<",
  gt: ">",
  quot: '"',
  apos: "'",
  nbsp: " ",
  ndash: "–",
  mdash: "—",
  lsquo: "‘",
  rsquo: "’",
  ldquo: "“",
  rdquo: "”",
  hellip: "…",
  bull: "•",
  middot: "·",
  copy: "©",
  reg: "®",
  trade: "™",
};

/** Decode HTML entities, which JSON-LD and meta values often carry escaped */
export function decodeEntities(str: string): string {
  return str.replace(
    /&(#x[0-9a-f]+|#\d+|[a-z]+);/gi,
    (match, entity: string) => {
      if (entity[0] == "#") {
        const code = entity[1].toLowerCase() == "x"
          ? parseInt(entity.slice(2), 16)
          : parseInt(entity.slice(1), 10);
        return Number.isNaN(code) ? match : String.fromCodePoint(code);
      }
      return NAMED_ENTITIES[entity.toLowerCase()] ?? match;
    },
  );
}

/** Convert an HTML fragment to plain text, keeping paragraph/line breaks */
export function htmlToText(html: string): string {
  return decodeEntities(
    html
      .replace(/<br\s*\/?>/gi, "\n")
      .replace(
        /<\/?(p|div|li|h[1-6]|tr|section|article|header)\b[^>]*>/gi,
        "\n",
      )
      .replace(/<[^>]+>/g, ""),
  )
    .replace(/[ \t ]+/g, " ")
    .replace(/ *\n */g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

/** Read a schema.org text value: a string, number, {"@value"}, or an array of them */
export function text(value: JsonValue): string | undefined {
  if (value == null) return undefined;
  if (Array.isArray(value)) {
    for (const item of value) {
      const result = text(item);
      if (result) return result;
    }
    return undefined;
  }
  if (typeof value == "number") return String(value);
  if (typeof value == "object") {
    return text(value["@value"]);
  }
  if (typeof value != "string") return undefined;
  const trimmed = value.trim();
  return trimmed ? trimmed : undefined;
}

/** A plain, entity-decoded text value with no markup */
export function plainText(value: JsonValue): string | undefined {
  const raw = text(value);
  if (!raw) return undefined;
  const result = /<[a-z!/][^>]*>/i.test(raw)
    ? htmlToText(raw)
    : decodeEntities(raw).trim();
  return result || undefined;
}

const TITLE_SEPARATOR = String.raw`\s*[|•·–—:\-]\s*`;

/** Remove a site name prepended or appended to a title, e.g. "Show — Venue".
 * Returns undefined when nothing is left but separators. */
export function stripSiteName(
  title: string | undefined,
  site: string | undefined,
): string | undefined {
  if (!title) return undefined;
  let result = title;
  if (site && site.toLowerCase() != title.toLowerCase()) {
    const escaped = site.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    result = result
      .replace(new RegExp(`${TITLE_SEPARATOR}${escaped}\\s*$`, "i"), "")
      .replace(new RegExp(`^\\s*${escaped}${TITLE_SEPARATOR}`, "i"), "");
  }
  result = result.replace(
    new RegExp(`^(${TITLE_SEPARATOR})+|(${TITLE_SEPARATOR})+$`, "g"),
    "",
  ).trim();
  return result || undefined;
}

/** Read a number that may be given as a numeric string */
export function number(value: JsonValue): number | undefined {
  const raw = text(value);
  if (raw == null) return undefined;
  const parsed = parseFloat(raw);
  return Number.isFinite(parsed) ? parsed : undefined;
}

/** Resolve a possibly relative or protocol-relative URL against the page */
export function absoluteUrl(
  value: string | undefined,
  base: URL,
): string | undefined {
  if (!value) return undefined;
  try {
    const url = new URL(decodeEntities(value.trim()), base);
    return url.protocol == "http:" || url.protocol == "https:"
      ? url.toString()
      : undefined;
  } catch (_e) {
    return undefined;
  }
}

/** Get the bare schema.org type names of a node, e.g. ["Event", "MusicEvent"] */
export function typeNames(node: JsonValue): string[] {
  if (!node || typeof node != "object") return [];
  const types = node["@type"] ?? node["type"];
  return (Array.isArray(types) ? types : [types])
    .filter((type): type is string => typeof type == "string")
    .map((type) => type.replace(/^.*[/:#]/, ""));
}

const EXTRA_EVENT_TYPES = new Set(["Festival", "EventSeries"]);

/** Whether a schema.org type name is Event or one of its subtypes */
export function isEventType(type: string): boolean {
  return type.endsWith("Event") || EXTRA_EVENT_TYPES.has(type);
}

/** Read an image value: a URL string, ImageObject, or an array of either */
export function image(
  value: JsonValue,
  base: URL,
  deref: Deref = identity,
): string | undefined {
  value = deref(value);
  if (value == null) return undefined;
  if (Array.isArray(value)) {
    for (const item of value) {
      const result = image(item, base, deref);
      if (result) return result;
    }
    return undefined;
  }
  if (typeof value == "string") return absoluteUrl(value, base);
  if (typeof value == "object") {
    return absoluteUrl(
      text(value.url) ?? text(value.contentUrl) ?? text(value["@id"]),
      base,
    );
  }
  return undefined;
}

/** Format a PostalAddress (or plain string address) as one line */
export function formatAddress(
  value: JsonValue,
  deref: Deref = identity,
): string | undefined {
  value = deref(value);
  if (value == null) return undefined;
  if (Array.isArray(value)) return formatAddress(value[0], deref);
  if (typeof value == "string") {
    // some sites pack address lines into one string with pipes or newlines
    const parts = value.split(/\s*[|\n]\s*/).map(plainText);
    return joinParts(parts);
  }
  if (typeof value != "object") return undefined;

  const parts = [
    value.streetAddress,
    value.addressLocality,
    value.addressRegion,
  ]
    .map(plainText);

  return joinParts(parts) ?? plainText(value.name);
}

/** Join address parts, skipping any already contained in an earlier part
 * (sites often put the whole address in streetAddress) */
function joinParts(parts: Array<string | undefined>): string | undefined {
  const kept: string[] = [];
  for (const part of parts) {
    if (!part) continue;
    const joined = kept.join(", ").toLowerCase();
    if (!joined.includes(part.toLowerCase())) kept.push(part);
  }
  return kept.length ? kept.join(", ") : undefined;
}

/** Venue names CMS templates fill in when the real one is missing */
const PLACEHOLDER_NAMES =
  /^(event )?(location|venue|place|address)s?$|^(tba|tbd|n\/a|none)$/i;

/** Combine a venue name and address, skipping whichever is redundant */
export function describeLocation(
  name: string | undefined,
  address: string | undefined,
): string | undefined {
  if (name && PLACEHOLDER_NAMES.test(name)) name = undefined;
  if (!name || !address) return name ?? address;

  const firstLine = address.split(",")[0].trim().toLowerCase();
  if (name.toLowerCase().includes(firstLine)) return name;
  if (address.toLowerCase().startsWith(name.toLowerCase())) return address;
  return `${name}, ${address}`;
}

interface LocationFields {
  location?: string;
  lat?: number;
  lon?: number;
}

/** Read a schema.org location: a string, Place, PostalAddress, VirtualLocation, or array */
export function location(
  value: JsonValue,
  deref: Deref = identity,
): LocationFields {
  value = deref(value);
  if (value == null) return {};

  if (Array.isArray(value)) {
    const items = value.map(deref);
    const physical = items.find((item) =>
      item && !typeNames(item).includes("VirtualLocation")
    );
    return location(physical ?? items[0], deref);
  }

  if (typeof value == "string") {
    // a bare URL is an online location, not a venue
    return /^https?:\/\//i.test(value.trim())
      ? {}
      : { location: plainText(value) };
  }

  if (typeof value != "object") return {};

  const types = typeNames(value);
  if (types.includes("VirtualLocation")) {
    return { location: plainText(value.name) ?? "Online" };
  }

  const name = plainText(value.name);
  const address = types.includes("PostalAddress")
    ? formatAddress(value)
    : formatAddress(value.address, deref);

  const geo = deref(value.geo) ?? value;
  const lat = number(geo?.latitude ?? value.latitude);
  const lon = number(geo?.longitude ?? value.longitude);
  const validGeo = lat != null && lon != null &&
    Math.abs(lat) <= 90 && Math.abs(lon) <= 180 && !(lat == 0 && lon == 0);

  return {
    location: describeLocation(name, address),
    lat: validGeo ? lat : undefined,
    lon: validGeo ? lon : undefined,
  };
}

/** Convert a schema.org Event node (from JSON-LD or microdata) to a Candidate */
export function eventNodeToCandidate(
  node: JsonValue,
  base: URL,
  deref: Deref = identity,
): Candidate {
  return {
    title: plainText(node.name) ?? plainText(node.headline),
    description: plainText(node.description),
    start: text(node.startDate) ?? text(node.doorTime),
    end: text(node.endDate),
    ...location(node.location, deref),
    image: image(node.image, base, deref),
  };
}
