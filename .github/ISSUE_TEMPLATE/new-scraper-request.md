---
name: New Scraper Request
about: Request support for scraping events from a new website
title: 'Add scraper: [SITE NAME]'
labels: enhancement, scraper, good first issue
assignees: ''
---

## Event Site Details

**Website Name:**

<!-- Name of the event platform/website -->

**Website URL:**

<!-- Main URL of the event platform -->

**Example Event URL:**

<!-- Link to a specific event on the platform that shows the typical URL pattern -->

## Technical Details

(Feel free to delete this section if you don't know what any of this means—if you do, try to provide as much information as you can for a potential implementer)

**API/SDK Resources:**

<!-- Links to any official API documentation, SDKs, or developer resources if available -->
<!-- Leave blank if unknown -->

**Structured Data:**

<!-- Does the event page include JSON-LD or other structured data? Check with https://search.google.com/test/rich-results -->
<!-- Leave blank if unknown -->

**Authentication Required:**

<!-- Is authentication required to view events? If yes, describe the type (e.g., API key, OAuth) -->

---

### Notes for Implementer

This scraper should be implemented following the patterns and best practices documented in [Event Scraper Development Guide](../supabase/functions/scrape-event/README.md).

Key implementation steps:

1. Check for structured data (JSON-LD) first
2. Look for official API/SDK options
3. Consider third-party libraries
4. Fall back to client-side extraction if needed

Remember to:

- Add example URLs in comments
- Document any rate limits
- Handle timezone conversion
- Add the scraper to sources/index.ts in appropriate order
