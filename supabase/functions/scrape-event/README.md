# Event Scraper Development Guide

This guide covers how to build new event scrapers for the SquadQuest platform. Scrapers extract structured event data from various websites and convert it to our common Event format.

## Architecture Overview

The scraping system tries each scraper in order (most specific to most generic) until one succeeds. Each scraper must implement:

```typescript
{
  canScrape(url: URL): boolean;  // Check if this scraper handles the URL
  scrape(url: URL): Promise<Event>;  // Extract event data
}
```

## Scraping Patterns

We have four main approaches for scraping event data, each with different tradeoffs:

### 1. Official API Integration

Best option when available. Uses site's official API with proper authentication.

Example (Eventbrite):

```typescript
const sdk = eventbrite({ token });
const eventData = await sdk.request(`/events/${eventId}`);
```

Testing:

```bash

# Test API endpoint directly
curl -H "Authorization: Bearer $EVENTBRITE_TOKEN" \
     https://www.eventbrite.com/api/v3/events/123
```

### 2. Third-Party Scraping Libraries

Uses maintained libraries that handle the scraping complexity.

Example (Facebook):

```typescript
import { scrapeFbEvent } from "facebook-event-scraper";
const eventData = await scrapeFbEvent(url);
```

Testing:

```bash
# Test scraper function
curl http://localhost:54321/functions/v1/scrape-event?url=https://facebook.com/events/123
```

### 3. Client-Side Data Extraction

Extracts data from client-side state or embedded scripts.

Example (Next.js data):

```typescript
const [, eventJson] = html.match(
  /<script id="__NEXT_DATA__" type="application\/json">(.*?)<\/script>/
);
const eventData = JSON.parse(eventJson).props.pageProps.event;
```

Development Tips:

1. Use browser DevTools to find data sources:
   - Network tab for API calls
   - Elements tab for embedded data
   - Sources tab for client state
2. Test selectors in Console before coding

### 4. Structured Data Parsing

Fallback approach using standard formats like JSON-LD.

Example:

```typescript
const scripts = html.match(
  /<script type="application\/ld\+json">(.*?)<\/script>/gs
);
const eventData = JSON.parse(scripts[0]);
```

Validation:

- Use [Google's Structured Data Testing Tool](https://search.google.com/test/rich-results)
- Check [Schema.org Event](https://schema.org/Event) documentation

## Development Workflow

1. **Initial Investigation**

   ```bash
   # Fetch the page and save HTML
   curl -L "https://example.com/events/123" > event.html

   # Look for JSON-LD data
   cat event.html | grep -A 1 "application/ld+json"
   ```

2. **Create Scraper Module**

   ```typescript
   // sources/example.ts
   export default {
     canScrape(url: URL) {
       return url.hostname === "example.com";
     },
     async scrape(url: URL) {
       // Your scraping logic here
     }
   }
   ```

3. **Register in sources/index.ts**

   ```typescript
   import example from "./example.ts";
   const scrapers = [
     example,
     // ... other scrapers
   ];
   ```

4. **Test Locally**

   The scraper function can be tested directly without running Supabase:

   1. Start the function using VSCode's Run and Debug (F5):
      - Select "Deno: scrape-event" configuration
      - Function will run on http://localhost:8001

   2. Use the api.http file to test different scrapers:

      ```http
      ### Test Facebook event
      GET http://localhost:8001/scrape-event
          ?url=https://www.facebook.com/events/123

      ### Test EventBrite event
      GET http://localhost:8001/scrape-event
          ?url=https://www.eventbrite.com/e/123

      ### Test Resident Advisor event
      GET http://localhost:8001/scrape-event
          ?url=https://ra.co/events/123
      ```

   3. Or test with curl:

      ```bash
      curl "http://localhost:8001/scrape-event?url=https://example.com/events/123"
      ```

## VSCode Setup & Debugging

1. **Required Extensions**
   - Deno (for Edge Functions)
   - REST Client (for testing with api.http)

2. **Launch Configuration**
   The workspace includes a launch configuration for the scraper in `.vscode/launch.json`

## Common Issues & Solutions

1. **Timezone Handling**
   - Always convert to UTC
   - Use moment-timezone or Temporal API
   - Store original timezone when available

2. **Dynamic Content**
   - Use Puppeteer for JavaScript-rendered content
   - Wait for specific elements/data to load
   - Handle loading states and timeouts

3. **Rate Limiting**
   - Add delays between requests
   - Handle 429 responses
   - Use API tokens when available

4. **Data Validation**
   - Assert required fields exist
   - Validate date formats
   - Check coordinate formats

## Testing Checklist

- [ ] URL pattern matching in canScrape()
- [ ] Required fields present in Event object
- [ ] Timezone handling correct
- [ ] Error cases handled gracefully
- [ ] Rate limiting respected
- [ ] Memory usage reasonable

## Best Practices

1. Start with JSON-LD/structured data if available
2. Fall back to official APIs if structured data insufficient
3. Use third-party libraries for complex sites
4. Client-side extraction as last resort
5. Always handle errors gracefully
6. Document rate limits and requirements
7. Include example URLs in comments
