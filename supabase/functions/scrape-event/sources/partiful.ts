import { assert } from "../../_shared/http.ts";
import { EventVisibility } from "../../_shared/squadquest.ts";
import { Event } from "../../_shared/squadquest.ts";

function canScrape(url: URL): boolean {
  return (
    (url.hostname == "www.partiful.com" || url.hostname == "partiful.com") &&
    url.pathname.toLowerCase().startsWith("/e/")
  );
}
async function scrape(url: URL): Promise<Event> {
  // load page from partiful
  const response = await fetch(url);
  assert(response.status == 200, "Failed to load event page from Partiful");

  // parse dom
  const html = await response.text();
  const [, eventJson] = html.match(
    /<script id="__NEXT_DATA__" type="application\/json">(.*?)<\/script>/,
  ) || [];

  assert(eventJson != null, "Failed to extract event data from Partiful");
  const eventData = JSON.parse(eventJson).props.pageProps.event;

  // fetch calendar file
  const calendarResponse = await fetch(eventData.calendarFile);
  const calendarText = await calendarResponse.text();

  const ical = await import("npm:node-ical");
  const calendarData = ical.sync.parseICS(calendarText);
  const calendarEventData =
    Object.values(calendarData).filter((entry) => entry.type == "VEVENT")[0];

  // build event object
  const startTime = new Date(eventData.startDate);

  // build event object
  return {
    title: eventData.title,
    start_time_min: startTime,
    start_time_max: startTime
      ? new Date(startTime.getTime() + 15 * 60 * 1000)
      : undefined,
    end_time: eventData.endDate ? new Date(eventData.endDate) : undefined,
    location_description: calendarEventData.location,
    link: calendarEventData.url || url.toString(),
    notes: eventData.description,
    banner_photo: eventData.image?.url,
    visibility: EventVisibility.public,
  };
}

// old HTML scraper implementation
// async function scrapeHtml(
//   url: URL,
//   localTimezoneOffset?: number,
// ): Promise<Event> {
//   const { JSDOM } = await import("https://cdn.esm.sh/jsdom-deno");

//   assert(
//     localTimezoneOffset != null,
//     "Local time zone required to scrape Partiful",
//   );

//   // load page from partiful
//   const response = await fetch(url);
//   assert(response.status == 200, "Failed to load event page from Partiful");

//   // parse dom
//   const html = await response.text();
//   const { window: { document } } = new JSDOM(html);

//   // parse start/end times
//   const dateScraped =
//     document.querySelector("time div div").childNodes[0].textContent;
//   const dateParsed = new Date(`${dateScraped}, ${new Date().getFullYear()}`);
//   const dateString = dateParsed
//     ? `${dateParsed.getFullYear()}-${
//       String(dateParsed.getMonth() + 1).padStart(2, "0")
//     }-${String(dateParsed.getDate()).padStart(2, "0")}`
//     : null;

//   // try to extract end time
//   let startTime, endTime;

//   const timeRangeBits = document.querySelector("time div + div").childNodes[0]
//     .textContent
//     .split(/\s*–\s*/);

//   if (dateString && timeRangeBits) {
//     const tzOffsetHours = Math.floor(localTimezoneOffset! / 60);
//     const tzOffsetMinutes = localTimezoneOffset! % 60;

//     if (timeRangeBits.length >= 1) {
//       let [, startHour, startMinute, startAMPM] = timeRangeBits[0].match(
//         /^(\d+):(\d+)(am|pm)$/i,
//       );

//       startHour = parseInt(startHour, 10);
//       startMinute = parseInt(startMinute, 10);

//       if (startAMPM.toLowerCase() == "pm") {
//         startHour += 12;
//       }

//       startHour -= tzOffsetHours;
//       startMinute -= tzOffsetMinutes;

//       startTime = new Date(
//         `${dateString}T${String(startHour).padStart(2, "0")}:${
//           String(startMinute).padStart(2, "0")
//         }:00Z`,
//       );
//     }

//     if (timeRangeBits.length == 2) {
//       let [, endHour, endMinute, endAMPM] = timeRangeBits[1].match(
//         /^(\d+):(\d+)(am|pm)$/i,
//       );

//       endHour = parseInt(endHour, 10);
//       endMinute = parseInt(endMinute, 10);

//       if (endAMPM.toLowerCase() == "pm") {
//         endHour += 12;
//       }

//       endHour -= tzOffsetHours;
//       endMinute -= tzOffsetMinutes;

//       endTime = new Date(
//         `${dateString}T${String(endHour).padStart(2, "0")}:${
//           String(endMinute).padStart(2, "0")
//         }:00Z`,
//       );

//       // TODO: handle multi-day ranges
//       if (startTime! > endTime) {
//         endTime.setDate(endTime.getDate() + 1);
//       }
//     }
//   }

//   // build event object
//   return {
//     title: document.querySelector("h1 span.summary").textContent,
//     start_time_min: startTime,
//     start_time_max: startTime
//       ? new Date(startTime.getTime() + 15 * 60 * 1000)
//       : undefined,
//     end_time: endTime,
//     location_description: document.querySelector(
//       'a[href^="https://www.google.com/maps/"]',
//     )
//       ?.textContent,
//     link: url.toString(),
//     notes: document.querySelector(".description")?.textContent,
//     banner_photo: document.querySelector("section img[srcset]")?.src,
//     visibility: EventVisibility.public,
//   };
// }

export default { canScrape, scrape };
