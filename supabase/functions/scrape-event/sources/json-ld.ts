import { assert } from "../../_shared/http.ts";
import { EventVisibility } from "../../_shared/squadquest.ts";
import { Event } from "../../_shared/squadquest.ts";

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

  // build event object
  const startTime = eventData.startDate
    ? new Date(eventData.startDate)
    : undefined;
  assert(startTime != null, "Event start time is required");

  return {
    title: eventData.name || "Untitled Event",
    start_time_min: startTime,
    start_time_max: startTime
      ? new Date(startTime.getTime() + 15 * 60 * 1000)
      : undefined,
    end_time: eventData.endDate ? new Date(eventData.endDate) : undefined,
    location_description: eventData.location?.name ||
      eventData.location?.address?.addressLocality,
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
