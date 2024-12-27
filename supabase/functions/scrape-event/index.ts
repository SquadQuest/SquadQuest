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

  // find source module
  let scrape: ((url: URL) => Promise<Event>) | null = null;

  for (const [scraperId, scraper] of Object.entries(scrapers)) {
    if (scraper.canScrape(url)) {
      console.log(`Scraping with ${scraperId}: ${url}`);
      scrape = scraper.scrape;
      break;
    }
  }

  assert(
    scrape != null,
    "SquadQuest does not yet support importing events from this site",
    404,
    "no-scraper-available",
  );

  // scrape event
  const event = await scrape!(url);

  // return event data
  return new Response(
    JSON.stringify(event),
    {
      headers: { "Content-Type": "application/json" },
      status: 200,
    },
  );
});
