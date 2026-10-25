import eventbrite from "./eventbrite.ts";
import facebook from "./facebook.ts";
import residentAdvisor from "./resident-advisor.ts";
import partiful from "./partiful.ts";
import axs from "./axs.ts";
import generic from "./generic/index.ts";
import { Scraper } from "./types.ts";

// Order matters - more specific scrapers first, fallback last
const scrapers: Scraper[] = [
  eventbrite,
  facebook,
  residentAdvisor,
  partiful,
  axs,
  generic, // Fallback scraper that reads standard metadata on any URL
];

export default scrapers;
