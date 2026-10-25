import {
  getRequiredJsonParameters,
  getRequiredQueryParameters,
  serve,
} from "../_shared/http.ts";
import { Event } from "../_shared/squadquest.ts";

/** Fill fields the app's event model requires as strings, so an import
 * missing them opens the form with blanks to fill instead of failing */
function forClient(event: Event): Event {
  return {
    ...event,
    title: event.title ?? "",
    location_description: event.location_description ?? "",
  };
}
import scrapers from "./sources/index.ts";
import flyerImage from "./sources/flyer-image.ts";

serve(async (request: Request) => {
  // POST: extract event details from a flyer image via an LLM vision model
  if (request.method === "POST") {
    const { image, mediaType, timezone } = await getRequiredJsonParameters(
      request,
      ["image", "mediaType", "timezone"],
    );

    const event = await flyerImage.extractFromImage(image, mediaType, timezone);

    return new Response(
      JSON.stringify(forClient(event)),
      {
        headers: { "Content-Type": "application/json" },
        status: 200,
      },
    );
  }

  // GET: scrape event details from a URL
  const { url: rawUrl } = getRequiredQueryParameters(
    request,
    [
      "url",
    ],
  );

  const url = new URL(rawUrl);
  const timezone = new URL(request.url).searchParams.get("timezone") ??
    undefined;

  // Try each scraper in order until one succeeds
  let lastError: Error | null = null;

  for (const scraper of scrapers) {
    if (scraper.canScrape(url)) {
      try {
        console.log(`Trying scraper: ${url}`);
        const event = await scraper.scrape(url, { timezone });
        return new Response(
          JSON.stringify(forClient(event)),
          {
            headers: { "Content-Type": "application/json" },
            status: 200,
          },
        );
      } catch (error) {
        console.log(`Scraper failed: ${error}`);
        lastError = error;
        // Continue to next scraper
      }
    }
  }

  // If we get here, no scraper succeeded
  return new Response(
    JSON.stringify({
      error: lastError?.message || "Failed to import event from this site",
      code: "scraping-failed",
    }),
    {
      headers: { "Content-Type": "application/json" },
      status: 404,
    },
  );
});
