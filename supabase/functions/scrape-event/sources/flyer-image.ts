import { assert } from "../../_shared/http.ts";
import { Event, EventVisibility } from "../../_shared/squadquest.ts";
import { getServiceRoleSupabaseClient } from "../../_shared/supabase.ts";

const ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages";
const MODEL = "claude-opus-4-8";

/** How many of the most-used topics to offer the model to choose from. */
const TOP_TOPICS_LIMIT = 25;

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
  topic: string | null;
}

/** Fetch the names of the most-used topics, ranked by how many events use each.
 * Best-effort: returns an empty result on any failure so extraction still works. */
async function getTopTopics(
  limit: number,
): Promise<{ names: string[]; idByName: Map<string, string> }> {
  const idByName = new Map<string, string>();
  try {
    const supabase = getServiceRoleSupabaseClient();
    const { data, error } = await supabase
      .from("topics")
      .select("id, name, instances(count)");

    if (error || !data) return { names: [], idByName };

    const ranked = data
      .filter((t: { name: string | null }) => !!t.name)
      .map((t: { id: string; name: string; instances: { count: number }[] }) => ({
        id: t.id,
        name: t.name,
        count: t.instances?.[0]?.count ?? 0,
      }))
      .filter((t) => t.count > 0)
      .sort((a, b) => b.count - a.count)
      .slice(0, limit);

    for (const t of ranked) idByName.set(t.name, t.id);
    return { names: ranked.map((t) => t.name), idByName };
  } catch (e) {
    console.error("Failed to load topics for flyer extraction:", e);
    return { names: [], idByName };
  }
}

function buildSchema(topicNames: string[]) {
  const properties: Record<string, unknown> = {
    is_event: {
      type: "boolean",
      description:
        "True only if the image is a flyer/poster/screenshot advertising a specific event.",
    },
    title: {
      type: ["string", "null"],
      description:
        "The event's name/title: the main name plus a subtitle or tour name if one reads as part of it (e.g. 'LOTUS: Eat the Light'). Transcribe verbatim — preserve original capitalization (including all-caps), punctuation, and wording; do not normalize casing, expand abbreviations, or rephrase. Do NOT include edition/version/anniversary qualifiers such as '10 Year Expanded Edition', 'Deluxe Edition', 'Remastered', or '20th Anniversary' — those belong in notes, not the title.",
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
        "A short description of the event drawn from the flyer (tagline, lineup, details), including any edition/version/anniversary qualifier kept out of the title (e.g. '10 Year Expanded Edition'). If the flyer has a tagline/slogan/hook, it must be the first line of notes, followed by the remaining details. Null if none.",
    },
  };

  const required = [
    "is_event",
    "title",
    "start_date_local",
    "start_max_local",
    "end_date_local",
    "location_description",
    "notes",
    "topic",
  ];

  // Offer the most-used topics as a closed set; null means "no good match".
  // enum alone constrains the value (the structured-output validator rejects
  // enum combined with a "type" array), and null in the list keeps it optional.
  properties.topic = {
    enum: [...topicNames, null],
    description: topicNames.length
      ? "The single best-matching category for this event, chosen ONLY from the allowed values. Pick a value only when it is a clear, quality match for what the flyer describes; otherwise return null. Do not force a weak match."
      : "Always null (no categories are available).",
  };

  return {
    type: "object",
    properties,
    required,
    additionalProperties: false,
  };
}

const PROMPT =
  `You are extracting structured event details from an event flyer, poster, or screenshot.
Read all visible text and return the event's details using the provided schema.
- The title is the main event name plus any subtitle/tour name only. Transcribe it verbatim, preserving the exact wording, capitalization (including all-caps styling), and punctuation shown — do not normalize, "fix", or rephrase it. Keep edition, version, anniversary, or "remastered/expanded/deluxe" qualifiers OUT of the title and put them in notes instead.
- Use the year shown on the flyer; if no year is given, assume the next occurrence of that date.
- Express all times as 24-hour local wall-clock values; do not apply any timezone offset.
- start_date_local and start_max_local define the window during which attendees should arrive/show up — not the event's full duration. Use the times on the flyer plus judgment about the event type to set a sensible arrival window:
  - A show or concert with separate "doors" and "show"/"start" times: doors -> start_date_local, show -> start_max_local.
  - A drop-in or come-anytime event (open house, party, festival "gates at X", happy hour): set a wider window reflecting when people would realistically show up.
  - A fixed call time (dinner reservation, ceremony, scheduled meetup): use the single time for start_date_local and leave start_max_local null.
  Don't invent precision the flyer doesn't support.
- If the event has a tagline, slogan, or one-line hook, make it the first line of notes, followed by the remaining details.
- For topic, choose the single best-matching value from the allowed list in the schema. Only pick one if it is clearly a good fit for the event; if none is a quality match, return null rather than forcing a weak fit.
- If the image is not advertising a specific event, set is_event to false and leave the other fields null.`;

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

  // Correct a mislabeled media type from the client against the actual bytes.
  const resolvedMediaType = detectImageMediaType(image, mediaType);

  // Offer the most-used topics for auto-categorization (best-effort).
  const { names: topicNames, idByName: topicIdByName } = await getTopTopics(
    TOP_TOPICS_LIMIT,
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
        format: { type: "json_schema", schema: buildSchema(topicNames) },
      },
      messages: [
        {
          role: "user",
          content: [
            {
              type: "image",
              source: {
                type: "base64",
                media_type: resolvedMediaType,
                data: image,
              },
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

  // Resolve the model's chosen topic name back to a {id, name} object so the
  // client form can pre-select it. Ignore anything not in the offered set.
  const topicId = extracted.topic ? topicIdByName.get(extracted.topic) : undefined;
  const topic = topicId
    ? { id: topicId, name: extracted.topic! }
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
    topic,
    visibility: EventVisibility.public,
  };
}

export default { extractFromImage };
