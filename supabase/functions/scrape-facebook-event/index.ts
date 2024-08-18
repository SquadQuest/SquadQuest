import {
  assertGet,
  getRequiredQueryParameters,
  serve,
} from "../_shared/http.ts";
import { scrapeFbEvent } from "npm:facebook-event-scraper";

serve(async (request) => {
  // process request
  assertGet(request);
  const { url } = getRequiredQueryParameters(
    request,
    [
      "url",
    ],
  );

  // scrape Facebook event page
  const eventData = await scrapeFbEvent(url);

  // build event object
  const startTimeMin = new Date(1000 * (eventData.startTimestamp - 15 * 60));
  const startTimeMax = new Date(1000 * eventData.startTimestamp);
  const endTime = eventData.endTimestamp
    ? new Date(1000 * eventData.endTimestamp)
    : null;

  const event = {
    start_time_min: startTimeMin.toISOString(),
    start_time_max: startTimeMax.toISOString(),
    end_time: endTime?.toISOString(),
    title: eventData.name,
    location_description: eventData.location?.name,
    rally_point_text: eventData.location?.coordinates
      ? `POINT(${eventData.location?.coordinates?.longitude} ${eventData.location?.coordinates?.latitude})`
      : null,
    link: eventData.url,
    notes: eventData.description,
    banner_photo: eventData.photo?.imageUri,
    visibility: "public",
  };

  // return event data
  return new Response(
    JSON.stringify(event),
    {
      headers: { "Content-Type": "application/json" },
      status: 200,
    },
  );
});
