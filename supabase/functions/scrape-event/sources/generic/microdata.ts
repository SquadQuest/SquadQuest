import { Document, Element, elements } from "./dom.ts";
import {
  Candidate,
  eventNodeToCandidate,
  isEventType,
  JsonValue,
} from "./normalize.ts";

/** The nearest itemscope that owns an itemprop element */
function owningScope(element: Element): Element | null {
  return element.parentElement?.closest("[itemscope]") ?? null;
}

/** Read one itemprop's value the way the microdata spec defines it */
function propValue(element: Element): JsonValue {
  if (element.hasAttribute("itemscope")) return readItem(element);

  const tag = element.tagName.toLowerCase();
  const attr = (name: string) => element.getAttribute(name) ?? undefined;

  if (element.hasAttribute("content")) return attr("content");
  if (tag == "time") return attr("datetime") ?? elementText(element);
  if (["img", "audio", "video", "source", "embed", "iframe"].includes(tag)) {
    return attr("src");
  }
  if (["a", "area", "link"].includes(tag)) return attr("href");
  if (["data", "meter"].includes(tag)) return attr("value");
  return elementText(element);
}

function elementText(element: Element): string {
  return element.textContent.replace(/\s+/g, " ").trim();
}

/** Turn an itemscope element into a schema.org-shaped object */
function readItem(scope: Element): JsonValue {
  const item: JsonValue = {
    "@type": (scope.getAttribute("itemtype") ?? "").split(/\s+/),
  };

  for (const element of elements(scope, "[itemprop]")) {
    if (owningScope(element) !== scope) continue;
    const value = propValue(element);
    for (const name of (element.getAttribute("itemprop") ?? "").split(/\s+/)) {
      // keep the first value of repeated properties
      if (name && item[name] == null) item[name] = value;
    }
  }

  return item;
}

/** Find the first schema.org Event described with microdata */
export function extractMicrodata(
  doc: Document,
  pageUrl: URL,
): Candidate | undefined {
  for (const scope of elements(doc, "[itemscope][itemtype]")) {
    const types = (scope.getAttribute("itemtype") ?? "")
      .split(/\s+/)
      .map((type) => type.replace(/^.*[/:#]/, ""));

    if (types.some(isEventType)) {
      return eventNodeToCandidate(readItem(scope), pageUrl);
    }
  }

  return undefined;
}
