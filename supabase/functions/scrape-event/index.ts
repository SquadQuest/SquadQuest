import { assert } from "../_shared/http.ts";
import {
  assertGet,
  getRequiredQueryParameters,
  serve,
} from "../_shared/http.ts";
import { Event } from "../_shared/squadquest.ts";
import scrapers from "./sources/index.ts";

serve(async (request: Request) => {
  // process request
  assertGet(request);
  const { url: rawUrl } = getRequiredQueryParameters(
    request,
    [
      "url",
    ],
  );

  const url = new URL(rawUrl);

  // Try each scraper in order until one succeeds
  let lastError: Error | null = null;

  for (const scraper of scrapers) {
    if (scraper.canScrape(url)) {
      try {
        console.log(`Trying scraper: ${url}`);
        const event = await scraper.scrape(url);
        return new Response(
          JSON.stringify(event),
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
