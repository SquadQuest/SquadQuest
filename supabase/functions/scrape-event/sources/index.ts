import eventbrite from "./eventbrite.ts";
import facebook from "./facebook.ts";
import residentAdvisor from "./resident-advisor.ts";
import partiful from "./partiful.ts";
import axs from "./axs.ts";
import jsonLd from "./json-ld.ts";

// Order matters - more specific scrapers first, fallback last
const scrapers = [
  eventbrite,
  facebook,
  residentAdvisor,
  partiful,
  axs,
  jsonLd, // Fallback scraper that tries JSON-LD on any URL
];

export default scrapers;
