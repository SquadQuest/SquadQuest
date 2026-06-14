import { assert } from "../../_shared/http.ts";
import { Event, EventVisibility } from "../../_shared/squadquest.ts";

const ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages";
const MODEL = "claude-opus-4-8";

/** Fields we ask the model to extract from a flyer image. Times are returned as
 * wall-clock local strings ("YYYY-MM-DDTHH:mm") since flyers rarely carry a
 * timezone or coordinates — the caller's timezone resolves them to UTC. */
interface ExtractedFlyer {
  is_event: boolean;
  title: string | null;
  start_date_local: string | null;
  start_max_local: string | null;
  end_date_local: string | null;
  location_description: string | null;
  notes: string | null;
}

const OUTPUT_SCHEMA = {
  type: "object",
  properties: {
    is_event: {
      type: "boolean",
      description:
        "True only if the image is a flyer/poster/screenshot advertising a specific event.",
    },
    title: {
      type: ["string", "null"],
      description:
        "The event's name/title, transcribed verbatim exactly as it appears on the flyer. Preserve original capitalization (including all-caps), punctuation, and wording — do not normalize casing, expand abbreviations, or rephrase. Include a subtitle or tour name as part of the title if it reads as one (e.g. 'LOTUS: Eat the Light').",
    },
    start_date_local: {
      type: ["string", "null"],
      description:
        "The EARLIEST time attendees should arrive, as local wall-clock time in 'YYYY-MM-DDTHH:mm' format (24-hour). For a show with separate doors and show times, this is the doors time. Otherwise it is the start time shown. Null if no date/time is shown.",
    },
    start_max_local: {
      type: ["string", "null"],
      description:
        "The LATEST time attendees should reasonably arrive, in 'YYYY-MM-DDTHH:mm' format. Together with start_date_local this defines the arrival window — when people should show up, not the event's full duration. For a show with doors/show times, use the show/start time. For a drop-in event (open house, party, 'gates at X'), use judgment to set a sensible later bound. Leave null for a fixed call time (dinner, ceremony, scheduled meetup) where everyone should arrive at one time.",
    },
    end_date_local: {
      type: ["string", "null"],
      description:
        "Event end as local wall-clock time in 'YYYY-MM-DDTHH:mm' format. Null if not shown.",
    },
    location_description: {
      type: ["string", "null"],
      description:
        "Venue name and/or address as written on the flyer. Null if not shown.",
    },
    notes: {
      type: ["string", "null"],
      description:
        "A short description of the event drawn from the flyer (tagline, lineup, details). If the flyer has a tagline/slogan/hook, it must be the first line of notes, followed by the remaining details. Null if none.",
    },
  },
  required: [
    "is_event",
    "title",
    "start_date_local",
    "start_max_local",
    "end_date_local",
    "location_description",
    "notes",
  ],
  additionalProperties: false,
};

const PROMPT =
  `You are extracting structured event details from an event flyer, poster, or screenshot.
Read all visible text and return the event's details using the provided schema.
- Transcribe the title verbatim, preserving the exact wording, capitalization (including all-caps styling), and punctuation shown. Do not normalize, "fix", or rephrase it.
- Use the year shown on the flyer; if no year is given, assume the next occurrence of that date.
- Express all times as 24-hour local wall-clock values; do not apply any timezone offset.
- start_date_local and start_max_local define the window during which attendees should arrive/show up — not the event's full duration. Use the times on the flyer plus judgment about the event type to set a sensible arrival window:
  - A show or concert with separate "doors" and "show"/"start" times: doors -> start_date_local, show -> start_max_local.
  - A drop-in or come-anytime event (open house, party, festival "gates at X", happy hour): set a wider window reflecting when people would realistically show up.
  - A fixed call time (dinner reservation, ceremony, scheduled meetup): use the single time for start_date_local and leave start_max_local null.
  Don't invent precision the flyer doesn't support.
- If the event has a tagline, slogan, or one-line hook, make it the first line of notes, followed by the remaining details.
- If the image is not advertising a specific event, set is_event to false and leave the other fields null.`;

/** Convert a wall-clock "YYYY-MM-DDTHH:mm" string in the given IANA timezone to a UTC Date. */
function localWallTimeToUtc(
  dateStr: string,
  timezone: string,
): Date | undefined {
  if (!dateStr.includes("T")) return undefined;

  const [datePart, timePart] = dateStr.split("T");
  const [year, month, day] = datePart.split("-").map(Number);
  const [hour, minute] = timePart.split(":").map(Number);

  if ([year, month, day, hour, minute].some((n) => Number.isNaN(n))) {
    return undefined;
  }

  try {
    const instant = new Temporal.PlainDateTime(year, month, day, hour, minute)
      .toZonedDateTime(timezone)
      .toInstant();
    return new Date(Number(instant.epochMilliseconds));
  } catch (e) {
    console.error("Failed to parse flyer date:", e);
    return undefined;
  }
}

/** Extract an Event from a base64-encoded flyer image using an Anthropic vision model. */
async function extractFromImage(
  image: string,
  mediaType: string,
  timezone: string,
): Promise<Event> {
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  assert(
    !!apiKey,
    "Cannot extract event from image, required ANTHROPIC_API_KEY missing from environment",
    500,
  );

  const response = await fetch(ANTHROPIC_API_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey!,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: 2000,
      output_config: {
        format: { type: "json_schema", schema: OUTPUT_SCHEMA },
      },
      messages: [
        {
          role: "user",
          content: [
            {
              type: "image",
              source: { type: "base64", media_type: mediaType, data: image },
            },
            { type: "text", text: PROMPT },
          ],
        },
      ],
    }),
  });

  if (!response.ok) {
    const detail = await response.text();
    throw new Error(
      `Anthropic request failed (${response.status}): ${detail}`,
    );
  }

  const result = await response.json();

  // structured output guarantees the first content block is text with valid JSON
  const textBlock = result.content?.find((b: { type: string }) =>
    b.type === "text"
  );
  assert(!!textBlock, "Model returned no extractable content");

  const extracted = JSON.parse(textBlock.text) as ExtractedFlyer;

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
    start_time_max: startTimeMax && startTimeMax.getTime() > startTime!.getTime()
      ? startTimeMax
      : new Date(startTime!.getTime() + 15 * 60 * 1000),
    end_time: endTime,
    location_description: extracted.location_description ?? undefined,
    notes: extracted.notes ?? undefined,
    visibility: EventVisibility.public,
  };
}

export default { extractFromImage };
