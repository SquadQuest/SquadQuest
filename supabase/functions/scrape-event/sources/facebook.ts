import { EventVisibility } from "../../_shared/squadquest.ts";
import { Event } from "../../_shared/squadquest.ts";

function canScrape(url: URL): boolean {
  return (
    (url.hostname == "www.facebook.com" || url.hostname == "facebook.com") &&
    url.pathname.toLowerCase().startsWith("/events/")
  );
}

/** The event's end time, which Facebook sends in a `"data":{...}` object
 * alongside the start time and timezone. facebook-event-scraper looks for it
 * too, but gives up at the first `"data":null` on the page, and Facebook pages
 * now have some ahead of the real one. */
function findEndTimestamp(
  html: string,
  startTimestamp: number,
  findJsonInString: (
    html: string,
    key: string,
  ) => { jsonData: Record<string, unknown> | null },
): number | undefined {
  const prefix = '"data":{';
  for (
    let index = html.indexOf(prefix);
    index != -1;
    index = html.indexOf(prefix, index + prefix.length)
  ) {
    try {
      const { jsonData } = findJsonInString(html.slice(index), "data");
      if (
        jsonData && "end_timestamp" in jsonData &&
        jsonData.start_timestamp === startTimestamp
      ) {
        return (jsonData.end_timestamp as number) || undefined;
      }
    } catch (_error) {
      // not valid JSON; keep looking
    }
  }
  return undefined;
}

/** Run an optional parser, treating a failure as missing data */
function optional<T>(parse: () => T): T | undefined {
  try {
    return parse();
  } catch (_error) {
    return undefined;
  }
}

async function scrape(url: URL): Promise<Event> {
  const { fetchEvent } = await import(
    "npm:facebook-event-scraper@0.1.2/dist/utils/network.js"
  );
  const parser = await import(
    "npm:facebook-event-scraper@0.1.2/dist/utils/htmlParser.js"
  );
  const { findJsonInString } = await import(
    "npm:facebook-event-scraper@0.1.2/dist/utils/json.js"
  );

  // scrape Facebook event page
  const html: string = await fetchEvent(url.toString());
  const eventData = parser.getBasicData(html);
  const endTimestamp = findEndTimestamp(
    html,
    eventData.startTimestamp,
    findJsonInString,
  );
  const location = eventData.isOnline
    ? undefined
    : optional(() => parser.getLocation(html));
  const description = optional(() => parser.getDescription(html));

  // build event object
  return {
    start_time_min: new Date(1000 * eventData.startTimestamp),
    start_time_max: new Date(1000 * (eventData.startTimestamp + 15 * 60)),
    end_time: endTimestamp ? new Date(1000 * endTimestamp) : undefined,
    title: eventData.name,
    location_description: location?.name,
    rally_point_text: location?.coordinates
      ? `POINT(${location.coordinates.longitude} ${location.coordinates.latitude})`
      : undefined,
    link: eventData.url,
    notes: description,
    banner_photo: eventData.photo?.imageUri,
    visibility: EventVisibility.public,
  };
}

export default { canScrape, scrape };
