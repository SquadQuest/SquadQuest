import { assert } from "../../_shared/http.ts";
import { EventVisibility } from "../../_shared/squadquest.ts";
import { Event } from "../../_shared/squadquest.ts";

/** Check if a date string includes timezone information */
function hasTimezoneInfo(dateStr: string): boolean {
  return dateStr.includes("Z") || // UTC
    dateStr.includes("+") || // Explicit offset
    dateStr.includes("-") && dateStr.split("-").length > 3; // Negative offset
}

/** Get timezone ID from geonames for a location */
async function getTimezoneId(
  lat: number,
  lon: number,
): Promise<string | null> {
  const response = await fetch(
    `http://api.geonames.org/timezoneJSON?username=squadquest&lat=${lat}&lng=${lon}`,
  );
  if (!response.ok) return null;
  const data = await response.json();
  return data.timezoneId || null;
}

/** Parse a wall time string with location information into a UTC Date */
async function parseWallTime(
  dateStr: string,
  lat: number | undefined,
  lon: number | undefined,
): Promise<Date | undefined> {
  if (!dateStr.includes("T")) return undefined;

  if (hasTimezoneInfo(dateStr)) {
    return new Date(dateStr);
  }

  if (!lat || !lon) return undefined;

  const timezoneId = await getTimezoneId(lat, lon);
  if (!timezoneId) return undefined;

  // Parse the wall time in the event's timezone using built-in Temporal API
  const [datePart, timePart] = dateStr.split("T");
  const [year, month, day] = datePart.split("-").map(Number);
  const [hour, minute] = timePart.split(":").map(Number);

  try {
    // Create a plain date time
    const plainDateTime = new Temporal.PlainDateTime(
      year,
      month,
      day,
      hour,
      minute,
    );

    // Convert to instant in the timezone
    const instant = plainDateTime.toZonedDateTime(timezoneId).toInstant();

    // Convert to Date
    return new Date(Number(instant.epochMilliseconds));
  } catch (e) {
    console.error("Failed to parse date:", e);
    return undefined;
  }
}

function canScrape(url: URL): boolean {
  // This is a fallback scraper, so we'll try it on any URL
  return true;
}

async function scrape(url: URL): Promise<Event> {
  // load page
  const response = await fetch(url);
  assert(response.status == 200, "Failed to load page");

  // parse dom
  const html = await response.text();
  const scripts =
    html.match(/<script type="application\/ld\+json">(.*?)<\/script>/gs) || [];
  let eventData = null;

  for (const script of scripts) {
    const jsonContent = script.replace(
      /<script type="application\/ld\+json">/,
      "",
    ).replace(/<\/script>/, "");
    try {
      const data = JSON.parse(jsonContent);
      // Look for event data in both direct object and array formats
      const eventObject = Array.isArray(data)
        ? data.find((item) =>
          item["@type"] === "Event" || item["@type"] === "MusicEvent"
        )
        : data;
      if (
        eventObject &&
        (eventObject["@type"] === "Event" ||
          eventObject["@type"] === "MusicEvent")
      ) {
        eventData = eventObject;
        break;
      }
    } catch (e) {
      continue;
    }
  }

  assert(eventData != null, "Failed to find event data in JSON-LD");

  // Get location coordinates
  const lat = eventData.location?.geo?.latitude;
  const lon = eventData.location?.geo?.longitude;

  // Parse start time
  const startTime = eventData.startDate
    ? await parseWallTime(eventData.startDate, lat, lon)
    : undefined;
  assert(startTime != null, "Could not determine event time");

  // Parse end time
  const endTime = eventData.endDate
    ? await parseWallTime(eventData.endDate, lat, lon)
    : undefined;

  return {
    title: eventData.name || undefined,
    start_time_min: startTime,
    start_time_max: startTime
      ? new Date(startTime.getTime() + 15 * 60 * 1000)
      : undefined,
    end_time: endTime,
    location_description: eventData.location?.name ||
      eventData.location?.address?.addressLocality,
    rally_point_text: lat && lon ? `POINT(${lon} ${lat})` : undefined,
    link: url.toString(),
    notes: eventData.description,
    banner_photo: typeof eventData.image === "string"
      ? eventData.image.startsWith("//")
        ? `https:${eventData.image}`
        : eventData.image
      : eventData.image?.url,
    visibility: EventVisibility.public,
  };
}

export default { canScrape, scrape };
