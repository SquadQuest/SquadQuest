import { EventVisibility } from "../../_shared/squadquest.ts";
import { Event } from "../../_shared/squadquest.ts";

function canScrape(url: URL): boolean {
  return (
    (url.hostname == "www.facebook.com" || url.hostname == "facebook.com") &&
    url.pathname.toLowerCase().startsWith("/events/")
  );
}

async function scrape(url: URL): Promise<Event> {
  const { scrapeFbEvent } = await import("npm:facebook-event-scraper");

  // scrape Facebook event page
  const eventData = await scrapeFbEvent(url.toString());

  // build event object
  return {
    start_time_min: new Date(1000 * eventData.startTimestamp),
    start_time_max: new Date(1000 * (eventData.startTimestamp + 15 * 60)),
    end_time: eventData.endTimestamp
      ? new Date(1000 * eventData.endTimestamp)
      : undefined,
    title: eventData.name,
    location_description: eventData.location?.name,
    rally_point_text: eventData.location?.coordinates
      ? `POINT(${eventData.location?.coordinates?.longitude} ${eventData.location?.coordinates?.latitude})`
      : undefined,
    link: eventData.url,
    notes: eventData.description,
    banner_photo: eventData.photo?.imageUri,
    visibility: EventVisibility.public,
  };
}

export default { canScrape, scrape };
