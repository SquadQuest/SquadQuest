import { assert } from "../_shared/http.ts";
import {
  assertGet,
  getRequiredQueryParameters,
  serve,
} from "../_shared/http.ts";

serve(async (request) => {
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
  let scrape: ((url: URL) => Event) | null = null;
  for await (const sourceFile of Deno.readDir("./sources")) {
    const source = await import(`./sources/${sourceFile.name}`);

    if (source.canScrape(url)) {
      console.log(`Scraping with ${sourceFile.name}: ${url}`);
      scrape = source.scrape;
      break;
    }
  }

  assert(
    scrape != null,
    "No event scraper found for URL",
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
