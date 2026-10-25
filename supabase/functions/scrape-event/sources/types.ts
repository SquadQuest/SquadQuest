import { Event } from "../../_shared/squadquest.ts";

/** Details about the import request a scraper may use */
export interface ScrapeContext {
  /** The importing device's IANA timezone, if it sent one */
  timezone?: string;
}

export interface Scraper {
  canScrape(url: URL): boolean;
  scrape(url: URL, context: ScrapeContext): Promise<Event>;
}
