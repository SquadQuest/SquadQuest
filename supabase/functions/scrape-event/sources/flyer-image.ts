import { assert } from "../../_shared/http.ts";
import { Event, EventVisibility } from "../../_shared/squadquest.ts";
import {
  buildSchema,
  getTopTopics,
  requestExtraction,
  resolveTopic,
  TOP_TOPICS_LIMIT,
} from "./lib/llm-extract.ts";
import { currentDateInZone, localWallTimeToUtc } from "./lib/time.ts";

function buildPrompt(today: string): string {
  return `You are extracting structured event details from an event flyer, poster, or screenshot.
Today's date is ${today} (in the event's local timezone). Use it to resolve any relative or incomplete dates.
Read all visible text and return the event's details using the provided schema.
- The title is the main event name plus any subtitle/tour name only. Transcribe it verbatim, preserving the exact wording, capitalization (including all-caps styling), and punctuation shown — do not normalize, "fix", or rephrase it. Keep edition, version, anniversary, or "remastered/expanded/deluxe" qualifiers OUT of the title and put them in notes instead.
- Prefer the year printed on the flyer. When no year is shown, choose the year that makes the date the next occurrence on or after today (${today}) — never default to a past year. Resolve relative dates such as "this Saturday" or "tomorrow" against today as well.
- Express all times as 24-hour local wall-clock values; do not apply any timezone offset.
- start_date_local and start_max_local define the window during which attendees should arrive/show up — not the event's full duration. Use the times on the flyer plus judgment about the event type to set a sensible arrival window:
  - A show or concert with separate "doors" and "show"/"start" times: doors -> start_date_local, show -> start_max_local.
  - A drop-in or come-anytime event (open house, party, festival "gates at X", happy hour): set a wider window reflecting when people would realistically show up.
  - A fixed call time (dinner reservation, ceremony, scheduled meetup): use the single time for start_date_local and leave start_max_local null.
  Don't invent precision the flyer doesn't support.
- If the event has a tagline, slogan, or one-line hook, make it the first line of notes, followed by the remaining details.
- For topic, choose the single best-matching value from the allowed list in the schema. Only pick one if it is clearly a good fit for the event; if none is a quality match, return null rather than forcing a weak fit.
- If the image is not advertising a specific event, set is_event to false and leave the other fields null.`;
}

/** Detect the image media type from the actual base64 bytes (magic numbers),
 * correcting a mislabeled mediaType from the client. Anthropic rejects the
 * request when the declared media type doesn't match the bytes, so this keeps
 * the endpoint working for clients that send the wrong type (e.g. a .png
 * screenshot the picker re-encoded as JPEG). Falls back to the declared type. */
function detectImageMediaType(base64Image: string, declared: string): string {
  try {
    // first 24 base64 chars decode to ~18 bytes — enough for any signature
    const head = atob(base64Image.slice(0, 24));
    const b = (i: number) => head.charCodeAt(i);
    if (b(0) === 0x89 && b(1) === 0x50 && b(2) === 0x4e && b(3) === 0x47) {
      return "image/png";
    }
    if (b(0) === 0xff && b(1) === 0xd8 && b(2) === 0xff) {
      return "image/jpeg";
    }
    if (b(0) === 0x47 && b(1) === 0x49 && b(2) === 0x46) {
      return "image/gif";
    }
    if (
      b(0) === 0x52 && b(1) === 0x49 && b(2) === 0x46 && b(3) === 0x46 &&
      b(8) === 0x57 && b(9) === 0x45 && b(10) === 0x42 && b(11) === 0x50
    ) {
      return "image/webp";
    }
  } catch (_e) {
    // fall through to the declared type
  }
  return declared;
}

/** Extract an Event from a base64-encoded flyer image using an Anthropic vision model. */
async function extractFromImage(
  image: string,
  mediaType: string,
  timezone: string,
): Promise<Event> {
  // Correct a mislabeled media type from the client against the actual bytes.
  const resolvedMediaType = detectImageMediaType(image, mediaType);

  // Anchor relative/incomplete dates to today in the caller's timezone.
  const today = currentDateInZone(timezone);

  // Offer the most-used topics for auto-categorization (best-effort).
  const { names: topicNames, idByName: topicIdByName } = await getTopTopics(
    TOP_TOPICS_LIMIT,
  );

  const extracted = await requestExtraction(
    [
      {
        type: "image",
        source: {
          type: "base64",
          media_type: resolvedMediaType,
          data: image,
        },
      },
      { type: "text", text: buildPrompt(today) },
    ],
    buildSchema(
      topicNames,
      "flyer",
      "True only if the image is a flyer/poster/screenshot advertising a specific event.",
    ),
  );

  assert(
    extracted.is_event,
    "This image does not appear to be an event flyer",
    404,
  );

  const startTime = extracted.start_date_local
    ? localWallTimeToUtc(extracted.start_date_local, timezone)
    : undefined;
  assert(startTime != null, "Could not determine event time from this image");

  // When the flyer splits doors vs show/start, use that as the start window;
  // otherwise default the latest start to 15 minutes after the earliest.
  const startTimeMax = extracted.start_max_local
    ? localWallTimeToUtc(extracted.start_max_local, timezone)
    : undefined;

  const endTime = extracted.end_date_local
    ? localWallTimeToUtc(extracted.end_date_local, timezone)
    : undefined;

  return {
    title: extracted.title ?? undefined,
    start_time_min: startTime,
    start_time_max:
      startTimeMax && startTimeMax.getTime() > startTime!.getTime()
        ? startTimeMax
        : new Date(startTime!.getTime() + 15 * 60 * 1000),
    end_time: endTime,
    location_description: extracted.location_description ?? undefined,
    notes: extracted.notes ?? undefined,
    topic: resolveTopic(extracted.topic, topicIdByName),
    visibility: EventVisibility.public,
  };
}

export default { extractFromImage };
