import { assert } from "../../../_shared/http.ts";
import { getServiceRoleSupabaseClient } from "../../../_shared/supabase.ts";

const ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages";
export const MODEL = "claude-opus-4-8";

/** How many of the most-used topics to offer the model to choose from. */
export const TOP_TOPICS_LIMIT = 25;

/** Fields we ask the model to extract. Times are returned as wall-clock local
 * strings ("YYYY-MM-DDTHH:mm") since sources rarely carry a timezone — the
 * caller resolves them to UTC. */
export interface ExtractedEvent {
  is_event: boolean;
  title: string | null;
  start_date_local: string | null;
  start_max_local: string | null;
  end_date_local: string | null;
  location_description: string | null;
  notes: string | null;
  topic: string | null;
}

export interface TopTopics {
  names: string[];
  idByName: Map<string, string>;
}

/** Fetch the names of the most-used topics, ranked by how many events use each.
 * Best-effort: returns an empty result on any failure so extraction still works. */
export async function getTopTopics(limit: number): Promise<TopTopics> {
  const idByName = new Map<string, string>();
  try {
    const supabase = getServiceRoleSupabaseClient();
    const { data, error } = await supabase
      .from("topics")
      .select("id, name, instances(count)");

    if (error || !data) return { names: [], idByName };

    const ranked = data
      .filter((t: { name: string | null }) => !!t.name)
      .map((
        t: { id: string; name: string; instances: { count: number }[] },
      ) => ({
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
    console.error("Failed to load topics for event extraction:", e);
    return { names: [], idByName };
  }
}

/** Build the structured-output schema. `subject` names the source in field
 * descriptions ("flyer", "page"), and `isEventDescription` says what counts as
 * an event for that source. */
export function buildSchema(
  topicNames: string[],
  subject: string,
  isEventDescription: string,
) {
  const properties: Record<string, unknown> = {
    is_event: {
      type: "boolean",
      description: isEventDescription,
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
        `Venue name and/or address as written on the ${subject}. Null if not shown.`,
    },
    notes: {
      type: ["string", "null"],
      description:
        `A short description of the event drawn from the ${subject} (tagline, lineup, details), including any edition/version/anniversary qualifier kept out of the title (e.g. '10 Year Expanded Edition'). If the ${subject} has a tagline/slogan/hook, it must be the first line of notes, followed by the remaining details. Format as clean Markdown, with '## ' (h2) headers for any sections and never '# ' (h1). Null if none.`,
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
      ? `The single best-matching category for this event, chosen ONLY from the allowed values. Pick a value only when it is a clear, quality match for what the ${subject} describes; otherwise return null. Do not force a weak match.`
      : "Always null (no categories are available).",
  };

  return {
    type: "object",
    properties,
    required,
    additionalProperties: false,
  };
}

/** Run a structured-output extraction against the Anthropic Messages API */
export async function requestExtraction(
  content: unknown[],
  schema: unknown,
): Promise<ExtractedEvent> {
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  assert(
    !!apiKey,
    "Cannot extract event details, required ANTHROPIC_API_KEY missing from environment",
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
        format: { type: "json_schema", schema },
      },
      messages: [{ role: "user", content }],
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

  return JSON.parse(textBlock.text) as ExtractedEvent;
}

/** Resolve the model's chosen topic name back to a {id, name} object so the
 * client form can pre-select it. Ignore anything not in the offered set. */
export function resolveTopic(
  topicName: string | null,
  idByName: Map<string, string>,
): { id: string; name: string } | undefined {
  const topicId = topicName ? idByName.get(topicName) : undefined;
  return topicId ? { id: topicId, name: topicName! } : undefined;
}
