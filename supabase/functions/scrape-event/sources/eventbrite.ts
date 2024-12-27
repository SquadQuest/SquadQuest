import { EventVisibility } from "../../_shared/squadquest.ts";
import { Event } from "../../_shared/squadquest.ts";

function canScrape(url: URL): boolean {
  return (
    (url.hostname == "www.eventbrite.com" ||
      url.hostname == "eventbrite.com") &&
    url.pathname.toLowerCase().startsWith("/e/")
  );
}

async function scrape(url: URL): Promise<Event> {
  // get token
  const token = Deno.env.get("EVENTBRITE_TOKEN");

  if (!token) {
    throw Error(
      "Cannot scrape Eventbrite event, required EVENTBRITE_TOKEN missing from environment",
    );
  }

  // extract event ID
  const [, eventId] = url.pathname.match(/(\d+)$/) || [];

  // load Eventbrite SDK
  const { default: { default: eventbrite } } = await import("npm:eventbrite");
  const sdk = eventbrite({ token });

  // read event
  // deno-lint-ignore no-explicit-any
  const eventData: any = await sdk.request(`/events/${eventId}?expand=venue`);

  // TODO: get structured content for description?: https://www.eventbrite.com/platform/api#/reference/structured-content/retrieve

  // build event object
  const startTime = new Date(eventData.start.utc);

  return {
    start_time_min: startTime,
    start_time_max: new Date(startTime.getTime() + 15 * 60 * 1000),
    end_time: new Date(eventData.end.utc),
    title: eventData.name.text,
    location_description: eventData.venue?.name,
    rally_point_text: eventData.venue?.latitude
      ? `POINT(${eventData.venue?.longitude} ${eventData.venue?.latitude})`
      : undefined,
    link: eventData.url,
    notes: eventData.description.text,
    banner_photo: eventData.logo.original.url,
    visibility: EventVisibility.public,
  };
}

export default { canScrape, scrape };
