import { Document } from "./dom.ts";
import { absoluteUrl, Candidate, number, plainText } from "./normalize.ts";

/** Read the first non-empty <meta> value among the given property/name keys */
function metaValue(doc: Document, ...keys: string[]): string | undefined {
  for (const key of keys) {
    for (const attr of ["property", "name", "itemprop"]) {
      const content = doc.querySelector(`meta[${attr}="${key}"]`)
        ?.getAttribute("content")
        ?.trim();
      if (content) return content;
    }
  }
  return undefined;
}

/** The site's own name, which page titles often carry as a suffix */
export function siteName(doc: Document): string | undefined {
  return plainText(metaValue(doc, "og:site_name", "application-name"));
}

/** Parse "lat;lon" or "lat, lon" as used by geo.position and ICBM meta tags */
function parseGeoPair(value: string | undefined) {
  const [lat, lon] = (value ?? "").split(/[;,]\s*/).map(Number);
  return Number.isFinite(lat) && Number.isFinite(lon) && !(lat == 0 && lon == 0)
    ? { lat, lon }
    : {};
}

/** Read OpenGraph, Twitter card, and plain HTML meta tags */
export function extractMeta(doc: Document, pageUrl: URL): Candidate {
  const lat = number(
    metaValue(
      doc,
      "place:location:latitude",
      "og:latitude",
      "event:location:latitude",
    ),
  );
  const lon = number(
    metaValue(
      doc,
      "place:location:longitude",
      "og:longitude",
      "event:location:longitude",
    ),
  );
  const geo = lat != null && lon != null
    ? { lat, lon }
    : parseGeoPair(metaValue(doc, "geo.position", "ICBM"));

  const locality = [
    metaValue(doc, "og:street-address"),
    metaValue(doc, "og:locality"),
    metaValue(doc, "og:region"),
  ].filter(Boolean).join(", ");

  return {
    title: plainText(
      metaValue(doc, "og:title", "twitter:title") ??
        doc.querySelector("title")?.textContent,
    ),
    description: plainText(
      metaValue(doc, "og:description", "twitter:description", "description"),
    ),
    start: metaValue(doc, "event:start_time", "startDate"),
    end: metaValue(doc, "event:end_time", "endDate"),
    location: plainText(locality || undefined),
    ...geo,
    image: absoluteUrl(
      metaValue(
        doc,
        "og:image:secure_url",
        "og:image",
        "twitter:image",
        "twitter:image:src",
      ),
      pageUrl,
    ),
  };
}
