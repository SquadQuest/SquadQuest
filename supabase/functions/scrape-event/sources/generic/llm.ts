import { Document, elements } from "./dom.ts";
import { htmlToText } from "./normalize.ts";
import {
  buildSchema,
  ExtractedEvent,
  getTopTopics,
  requestExtraction,
  resolveTopic,
  TOP_TOPICS_LIMIT,
} from "../lib/llm-extract.ts";

/** How much page text to send the model; event details sit near the top */
const MAX_TEXT_LENGTH = 15_000;

export interface LlmResult {
  extracted: ExtractedEvent;
  topic?: { id: string; name: string };
}

/** Extract event details from page text, given hints already found in metadata */
export type ExtractFromText = (
  text: string,
  hints: Record<string, string>,
  today: string,
) => Promise<LlmResult>;

/** The page's readable text, without scripts, styles, and site chrome. This
 * removes elements from `doc`, so run it after the metadata extractors. */
export function pageText(doc: Document): string {
  for (
    const element of elements(
      doc,
      "script, style, noscript, template, svg, iframe, nav, footer",
    )
  ) {
    element.remove();
  }

  const body = doc.body?.innerHTML ?? "";
  return htmlToText(body).slice(0, MAX_TEXT_LENGTH);
}

function buildPrompt(
  text: string,
  hints: Record<string, string>,
  today: string,
): string {
  const hintLines = Object.entries(hints)
    .map(([key, value]) => `- ${key}: ${value}`)
    .join("\n");

  return `You are extracting structured event details from the text of an event web page.
Today's date is ${today} (in the event's local timezone). Use it to resolve any relative or incomplete dates.
${
    hintLines
      ? `The page's metadata already provided these values. They may be incomplete (for example a date with no time); use them as anchors and fill in what's missing from the page text:\n${hintLines}\n`
      : ""
  }
Return the event's details using the provided schema.
- The title is the main event name plus any subtitle/tour name only. Transcribe it verbatim, preserving the exact wording, capitalization, and punctuation shown — do not normalize, "fix", or rephrase it. Leave out site names and separators that page titles often append (e.g. " | Venue Name"). Keep edition, version, anniversary, or "remastered/expanded/deluxe" qualifiers OUT of the title and put them in notes instead.
- Prefer the year printed on the page. When no year is shown, choose the year that makes the date the next occurrence on or after today (${today}) — never default to a past year. Resolve relative dates such as "this Saturday" or "tomorrow" against today as well.
- Express all times as 24-hour local wall-clock values; do not apply any timezone offset.
- start_date_local and start_max_local define the window during which attendees should arrive/show up — not the event's full duration. Use the times on the page plus judgment about the event type to set a sensible arrival window:
  - A show or concert with separate "doors" and "show"/"start" times: doors -> start_date_local, show -> start_max_local.
  - A drop-in or come-anytime event (open house, party, festival "gates at X", happy hour): set a wider window reflecting when people would realistically show up.
  - A fixed call time (dinner reservation, ceremony, scheduled meetup): use the single time for start_date_local and leave start_max_local null.
  Don't invent precision the page doesn't support.
- Ignore unrelated content such as other upcoming events, navigation, ads, and cookie notices.
- If the event has a tagline, slogan, or one-line hook, make it the first line of notes, followed by the remaining details. Keep notes short.
- Write notes as clean Markdown: plain paragraphs separated by blank lines, "- " bullet lists, and **bold** or links only where the page uses them. If the details have sections, give each a "## " (h2) header; never use "# " (h1), and use "### " only for subsections under an h2. Don't wrap notes in a code block, and leave out leftover HTML, entities, and page chrome like "Share" or "Buy tickets" buttons.
- For topic, choose the single best-matching value from the allowed list in the schema. Only pick one if it is clearly a good fit for the event; if none is a quality match, return null rather than forcing a weak fit.
- If the page is not about one specific event (for example a listing of many events, a venue homepage, or an error page), set is_event to false and leave the other fields null.

Page text:
"""
${text}
"""`;
}

/** Extract event details from page text using an Anthropic model */
export const extractFromText: ExtractFromText = async (text, hints, today) => {
  const { names: topicNames, idByName } = await getTopTopics(TOP_TOPICS_LIMIT);

  const extracted = await requestExtraction(
    [{ type: "text", text: buildPrompt(text, hints, today) }],
    buildSchema(
      topicNames,
      "page",
      "True only if the page describes one specific event.",
    ),
  );

  return { extracted, topic: resolveTopic(extracted.topic, idByName) };
};
