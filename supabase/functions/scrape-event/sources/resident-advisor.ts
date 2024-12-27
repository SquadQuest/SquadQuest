import { EventVisibility } from "../../_shared/squadquest.ts";
import { Event } from "../../_shared/squadquest.ts";

function canScrape(url: URL): boolean {
  return (
    (url.hostname == "www.ra.co" ||
      url.hostname == "ra.co") &&
    url.pathname.toLowerCase().startsWith("/events/")
  );
}

async function scrape(url: URL): Promise<Event> {
  // extract event ID
  const [, eventId] = url.pathname.match(/^\/events\/(\d+)/) || [];

  // load GraphQL client
  const { gql, request } = await import(
    "https://deno.land/x/graphql_request/mod.ts"
  );

  // read event
  const query = gql`
    query GET_EVENT_DETAIL($id: ID!) {
      event(id: $id) {
        title
        startTime
        endTime
        contentUrl
        content
        images {
          filename
          type
        }
        venue {
          name
          location {
            latitude
            longitude
          }
        }
      }
    }
  `;

  const { event: eventData } = await request(
    "https://ra.co/graphql",
    query,
    { id: eventId },
  );

  // build event object
  const startTime = new Date(eventData.startTime);

  return {
    start_time_min: startTime,
    start_time_max: new Date(startTime.getTime() + 15 * 60 * 1000),
    end_time: eventData.endTime ? new Date(eventData.endTime) : undefined,
    title: eventData.title,
    location_description: eventData.venue?.name,
    rally_point_text: eventData.venue?.location
      ? `POINT(${eventData.venue?.location.longitude} ${eventData.venue?.location.latitude})`
      : undefined,
    link: `https://ra.co/events/${eventData.contentUrl}`,
    notes: eventData.content,
    banner_photo: eventData.images.length > 0
      ? eventData.images[0].filename
      : undefined,
    visibility: EventVisibility.public,
  };
}

export default { canScrape, scrape };
