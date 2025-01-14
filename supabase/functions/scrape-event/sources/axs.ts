import { assert } from "../../_shared/http.ts";
import { EventVisibility } from "../../_shared/squadquest.ts";
import { Event } from "../../_shared/squadquest.ts";

function canScrape(url: URL): boolean {
  return (
    url.hostname === "www.axs.com" &&
    url.pathname.toLowerCase().startsWith("/events/")
  );
}

async function scrape(url: URL): Promise<Event> {
  // Import puppeteer
  const { default: puppeteer } = await import(
    "https://deno.land/x/puppeteer@16.2.0/mod.ts"
  );

  // Launch browser
  const browser = await puppeteer.connect({
    browserWSEndpoint: "ws://chrome:3000",
  });

  try {
    // Create a new page with stealth settings
    const page = await browser.newPage();

    // Navigate to URL
    await page.goto(url.toString(), {
      waitUntil: "domcontentloaded",
      timeout: 60000,
    });

    // Get page content
    const html = await page.content();

    // Find all ld+json scripts and look for the one containing event data
    const scripts =
      html.match(/<script type="application\/ld\+json">(.*?)<\/script>/gs) ||
      [];
    let eventData = null;

    for (const script of scripts) {
      const jsonContent = script.replace(
        /<script type="application\/ld\+json">/,
        "",
      ).replace(/<\/script>/, "");
      try {
        const data = JSON.parse(jsonContent);
        if (data["@type"] === "Event" || data["@type"] === "MusicEvent") {
          eventData = data;
          break;
        }
      } catch (e) {
        continue;
      }
    }

    assert(eventData != null, "Failed to extract event data from AXS");

    try {
      // build event object
      const startTime = eventData.startDate
        ? new Date(eventData.startDate)
        : undefined;
      assert(startTime != null, "Event start time is required");

      return {
        title: eventData.name || "Untitled Event",
        start_time_min: startTime,
        start_time_max: startTime
          ? new Date(startTime.getTime() + 15 * 60 * 1000)
          : undefined,
        end_time: eventData.endDate ? new Date(eventData.endDate) : undefined,
        location_description: eventData.location?.name ||
          eventData.location?.address?.addressLocality,
        link: url.toString(),
        notes: eventData.description || undefined,
        banner_photo: typeof eventData.image === "string"
          ? eventData.image.startsWith("//")
            ? `https:${eventData.image}`
            : eventData.image
          : undefined,
        visibility: EventVisibility.public,
      };
    } catch (error) {
      throw new Error(`Failed to parse AXS event data: ${error.message}`);
    }
  } finally {
    await browser.close();
  }
}

export default { canScrape, scrape };
