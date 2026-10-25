/** A wall-clock date (and optionally time) with no timezone attached. */
export interface WallTime {
  year: number;
  month: number;
  day: number;
  hour?: number;
  minute?: number;
}

/** A parsed date value: either an absolute instant, or a wall time that still
 * needs a timezone to become one. */
export type ParsedTime = { instant: Date } | { local: WallTime };

const ISO_PATTERN =
  /^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{1,2}):(\d{2})(?::(\d{2})(?:[.,]\d+)?)?)?\s*(Z|[+-]\d{2}:?\d{2})?$/i;

/** Matches a trailing zone marker on a non-ISO date string */
const ZONE_MARKER = /(\bGMT\b|\bUTC\b|\bZ$|[+-]\d{2}:?\d{2}$)/i;

/** Parse a date string from page metadata. ISO strings with an offset (and any
 * Date object) become instants; ISO strings without one become wall times.
 * Loose strings like "May 1, 2026 7:00 PM" are parsed as wall times too. */
export function parseTimeValue(
  value: string | Date | undefined | null,
): ParsedTime | undefined {
  if (value == null) return undefined;

  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? undefined : { instant: value };
  }

  const str = value.trim();
  if (!str) return undefined;

  const iso = str.match(ISO_PATTERN);
  if (iso) {
    const [, year, month, day, hour, minute, second, offset] = iso;

    if (offset && hour != null) {
      const normalizedOffset = offset.toUpperCase() == "Z"
        ? "Z"
        : offset.includes(":")
        ? offset
        : `${offset.slice(0, 3)}:${offset.slice(3)}`;
      const date = new Date(
        `${year}-${month}-${day}T${hour.padStart(2, "0")}:${minute}:${
          second ?? "00"
        }${normalizedOffset}`,
      );
      return Number.isNaN(date.getTime()) ? undefined : { instant: date };
    }

    return {
      local: {
        year: Number(year),
        month: Number(month),
        day: Number(day),
        hour: hour != null ? Number(hour) : undefined,
        minute: minute != null ? Number(minute) : undefined,
      },
    };
  }

  // non-ISO: honor an explicit zone, otherwise read it as a wall time
  if (ZONE_MARKER.test(str)) {
    const date = new Date(str);
    if (!Number.isNaN(date.getTime())) return { instant: date };
  }

  const wall = new Date(`${str} UTC`);
  if (Number.isNaN(wall.getTime())) return undefined;
  const hasTime = /\d:\d{2}|\d\s*[ap]\.?m\b/i.test(str);
  return {
    local: {
      year: wall.getUTCFullYear(),
      month: wall.getUTCMonth() + 1,
      day: wall.getUTCDate(),
      hour: hasTime ? wall.getUTCHours() : undefined,
      minute: hasTime ? wall.getUTCMinutes() : undefined,
    },
  };
}

/** Whether a string names a timezone Temporal can use */
export function isValidTimezone(timezone: string | undefined): boolean {
  if (!timezone) return false;
  try {
    Temporal.Now.plainDateISO(timezone);
    return true;
  } catch (_e) {
    return false;
  }
}

/** Convert a wall time in the given IANA timezone to a UTC Date. A wall time
 * without an hour is placed at `defaultHour` on that day. */
export function wallTimeToUtc(
  wall: WallTime,
  timezone: string,
  defaultHour = 12,
): Date | undefined {
  const { year, month, day } = wall;
  const hour = wall.hour ?? defaultHour;
  const minute = wall.hour == null ? 0 : wall.minute ?? 0;

  if ([year, month, day, hour, minute].some((n) => Number.isNaN(n))) {
    return undefined;
  }

  try {
    const instant = new Temporal.PlainDateTime(year, month, day, hour, minute)
      .toZonedDateTime(timezone)
      .toInstant();
    return new Date(Number(instant.epochMilliseconds));
  } catch (e) {
    console.error("Failed to convert wall time:", e);
    return undefined;
  }
}

/** Convert a wall-clock "YYYY-MM-DDTHH:mm" string in the given IANA timezone to a UTC Date. */
export function localWallTimeToUtc(
  dateStr: string,
  timezone: string,
): Date | undefined {
  if (!dateStr.includes("T")) return undefined;

  const parsed = parseTimeValue(dateStr);
  if (!parsed || !("local" in parsed) || parsed.local.hour == null) {
    return undefined;
  }

  return wallTimeToUtc(parsed.local, timezone);
}

/** Today's date ("YYYY-MM-DD") in the given IANA timezone, for resolving
 * incomplete or relative dates. Falls back to UTC. */
export function currentDateInZone(
  timezone: string,
  now: Date = new Date(),
): string {
  const instant = Temporal.Instant.fromEpochMilliseconds(now.getTime());
  try {
    return instant.toZonedDateTimeISO(timezone).toPlainDate().toString();
  } catch (_e) {
    return instant.toZonedDateTimeISO("UTC").toPlainDate().toString();
  }
}

/** Get timezone ID from geonames for a location */
export async function lookupTimezoneByGeo(
  lat: number,
  lon: number,
): Promise<string | null> {
  try {
    const response = await fetch(
      `https://secure.geonames.org/timezoneJSON?username=squadquest&lat=${lat}&lng=${lon}`,
      { signal: AbortSignal.timeout(5000) },
    );
    if (!response.ok) return null;
    const data = await response.json();
    return data.timezoneId || null;
  } catch (e) {
    console.error("Timezone lookup failed:", e);
    return null;
  }
}
