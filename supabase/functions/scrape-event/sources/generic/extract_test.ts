import {
  assert,
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { extractFromHtml, ExtractOptions } from "./index.ts";
import { ExtractFromText } from "./llm.ts";
import { ExtractedEvent } from "../lib/llm-extract.ts";

const PAGE = new URL("https://venue.example/events/big-show/");

/** Options that keep tests offline: no geonames, calendar fetches, or LLM */
function offline(overrides: ExtractOptions = {}): ExtractOptions {
  return {
    lookupTimezone: () => Promise.resolve(null),
    fetchCalendar: () => Promise.reject(new Error("no network in tests")),
    llm: null,
    ...overrides,
  };
}

/** Enough body text that the page isn't treated as an empty app shell */
const FILLER = `<p>${"Details about the event. ".repeat(10)}</p>`;

function page(head: string, body = "") {
  return `<!doctype html><html><head>${head}</head><body>${body}</body></html>`;
}

function jsonLd(data: unknown, attrs = 'type="application/ld+json"') {
  return `<script ${attrs}>${JSON.stringify(data)}</script>`;
}

function stubLlm(
  extracted: Partial<ExtractedEvent>,
  calls: Array<Record<string, string>> = [],
): ExtractFromText {
  return (_text, hints) => {
    calls.push(hints);
    return Promise.resolve({
      extracted: {
        is_event: true,
        title: null,
        start_date_local: null,
        start_max_local: null,
        end_date_local: null,
        location_description: null,
        notes: null,
        topic: null,
        ...extracted,
      },
    });
  };
}

const iso = (date: Date | undefined) => date?.toISOString();

Deno.test("reads a plain top-level JSON-LD Event", async () => {
  const event = await extractFromHtml(
    page(jsonLd({
      "@context": "https://schema.org",
      "@type": "Event",
      name: "Big Show",
      startDate: "2026-11-14T19:00:00-05:00",
      endDate: "2026-11-14T22:00:00-05:00",
      location: {
        "@type": "Place",
        name: "The Hall",
        geo: { latitude: 39.95, longitude: -75.16 },
      },
      image: "//cdn.example/show.jpg",
      description: "<p>Doors at 7.</p><p>All ages &amp; welcome</p>",
    })),
    PAGE,
    offline(),
  );

  assertEquals(event.title, "Big Show");
  assertEquals(iso(event.start_time_min), "2026-11-15T00:00:00.000Z");
  assertEquals(iso(event.start_time_max), "2026-11-15T00:15:00.000Z");
  assertEquals(iso(event.end_time), "2026-11-15T03:00:00.000Z");
  assertEquals(event.location_description, "The Hall");
  assertEquals(event.rally_point_text, "POINT(-75.16 39.95)");
  assertEquals(event.banner_photo, "https://cdn.example/show.jpg");
  assertEquals(event.notes, "Doors at 7.\n\nAll ages & welcome");
});

Deno.test("finds an Event inside a Yoast-style @graph with @id references", async () => {
  const event = await extractFromHtml(
    page(jsonLd({
      "@context": "https://schema.org",
      "@graph": [
        { "@type": "WebPage", "@id": PAGE.href, name: "Big Show | Venue" },
        {
          "@type": "Place",
          "@id": "#venue",
          name: "The Hall",
          address: {
            "@type": "PostalAddress",
            streetAddress: "1 Main St",
            addressLocality: "Philadelphia",
          },
        },
        {
          "@type": "Event",
          name: "Big Show",
          startDate: "2026-11-14T19:00:00Z",
          location: { "@id": "#venue" },
          image: { "@id": "#img" },
        },
        { "@type": "ImageObject", "@id": "#img", url: "/img/show.jpg" },
      ],
    })),
    PAGE,
    offline(),
  );

  assertEquals(event.title, "Big Show");
  assertEquals(event.location_description, "The Hall, 1 Main St, Philadelphia");
  assertEquals(event.banner_photo, "https://venue.example/img/show.jpg");
});

Deno.test("accepts an array @type, prefixed types, and odd script attributes", async () => {
  const event = await extractFromHtml(
    page(
      jsonLd(
        {
          "@type": ["schema:Event", "MusicEvent"],
          name: "Band Night",
          startDate: "2026-11-14T19:00:00+0100",
        },
        "id='event-data' type='application/ld+json' class=\"yoast\"",
      ),
    ),
    PAGE,
    offline(),
  );

  assertEquals(event.title, "Band Night");
  assertEquals(iso(event.start_time_min), "2026-11-14T18:00:00.000Z");
});

Deno.test("tolerates broken JSON-LD: raw newlines, trailing commas, CDATA", async () => {
  const html = page(`<script type="application/ld+json">//<![CDATA[
    {"@type": "Event", "name": "Line
Break", "startDate": "2026-11-14T19:00:00Z",}
  //]]></script>`);
  const event = await extractFromHtml(html, PAGE, offline());
  assertEquals(event.title, "Line Break");
});

Deno.test("prefers the event matching the page URL on a page with several", async () => {
  const event = await extractFromHtml(
    page(jsonLd([
      {
        "@type": "Event",
        name: "Other Show",
        url: "https://venue.example/events/other/",
        startDate: "2026-11-01T19:00:00Z",
      },
      {
        "@type": "Event",
        name: "Big Show",
        url: "https://www.venue.example/events/big-show",
        startDate: "2026-11-14T19:00:00Z",
      },
    ])),
    PAGE,
    offline(),
  );
  assertEquals(event.title, "Big Show");
});

Deno.test("resolves wall times via geo lookup, then device timezone", async () => {
  const html = page(jsonLd({
    "@type": "Event",
    name: "Local Time",
    startDate: "2026-11-14T19:00",
    location: { "@type": "Place", latitude: "40.7", longitude: "-74.0" },
  }));

  const viaGeo = await extractFromHtml(
    html,
    PAGE,
    offline({
      lookupTimezone: () => Promise.resolve("America/New_York"),
      timezone: "America/Los_Angeles",
    }),
  );
  assertEquals(iso(viaGeo.start_time_min), "2026-11-15T00:00:00.000Z");

  const viaDevice = await extractFromHtml(
    html,
    PAGE,
    offline({ timezone: "America/Los_Angeles" }),
  );
  assertEquals(iso(viaDevice.start_time_min), "2026-11-15T03:00:00.000Z");
});

Deno.test("places a date-only start at midday without an LLM", async () => {
  const event = await extractFromHtml(
    page(
      jsonLd({ "@type": "Festival", name: "Fair", startDate: "2026-11-14" }),
    ),
    PAGE,
    offline({ timezone: "America/Chicago" }),
  );
  assertEquals(iso(event.start_time_min), "2026-11-14T18:00:00.000Z");
});

Deno.test("fills a date-only start's time from the LLM when the day matches", async () => {
  const calls: Array<Record<string, string>> = [];
  const html = page(
    jsonLd({ "@type": "Event", name: "Fair", startDate: "2026-11-14" }),
    FILLER,
  );

  const event = await extractFromHtml(
    html,
    PAGE,
    offline({
      timezone: "America/Chicago",
      llm: stubLlm({
        start_date_local: "2026-11-14T10:00",
        start_max_local: "2026-11-14T14:00",
      }, calls),
    }),
  );
  assertEquals(iso(event.start_time_min), "2026-11-14T16:00:00.000Z");
  assertEquals(iso(event.start_time_max), "2026-11-14T20:00:00.000Z");
  assertEquals(calls[0], { title: "Fair", start: "2026-11-14" });

  const mismatched = await extractFromHtml(
    html,
    PAGE,
    offline({
      timezone: "America/Chicago",
      llm: stubLlm({ start_date_local: "2026-12-01T10:00" }),
    }),
  );
  assertEquals(iso(mismatched.start_time_min), "2026-11-14T18:00:00.000Z");

  // the model's midnight means it found no time either
  const midnight = await extractFromHtml(
    html,
    PAGE,
    offline({
      timezone: "America/Chicago",
      llm: stubLlm({ start_date_local: "2026-11-14T00:00" }),
    }),
  );
  assertEquals(iso(midnight.start_time_min), "2026-11-14T18:00:00.000Z");
});

Deno.test("reads string, array, and address-only locations", async () => {
  const withLocation = (location: unknown) =>
    extractFromHtml(
      page(jsonLd({
        "@type": "Event",
        name: "x",
        startDate: "2026-11-14T19:00:00Z",
        location,
      })),
      PAGE,
      offline(),
    );

  assertEquals(
    (await withLocation("Central Park")).location_description,
    "Central Park",
  );
  assertEquals(
    (await withLocation([
      { "@type": "VirtualLocation", url: "https://zoom.example" },
      { "@type": "Place", name: "Library" },
    ])).location_description,
    "Library",
  );
  assertEquals(
    (await withLocation({
      "@type": "Place",
      address: "500 Elm St, Springfield",
    })).location_description,
    "500 Elm St, Springfield",
  );
  assertEquals(
    (await withLocation({
      "@type": "PostalAddress",
      streetAddress: "1 Main St",
      addressLocality: "Springfield",
      addressRegion: "IL",
    })).location_description,
    "1 Main St, Springfield, IL",
  );
});

Deno.test("reads an image array of ImageObjects", async () => {
  const event = await extractFromHtml(
    page(jsonLd({
      "@type": "Event",
      name: "x",
      startDate: "2026-11-14T19:00:00Z",
      image: [{
        "@type": "ImageObject",
        contentUrl: "https://cdn.example/a.jpg",
      }],
    })),
    PAGE,
    offline(),
  );
  assertEquals(event.banner_photo, "https://cdn.example/a.jpg");
});

Deno.test("reads microdata events", async () => {
  const event = await extractFromHtml(
    page(
      "",
      `<div itemscope itemtype="https://schema.org/TheaterEvent">
        <h1 itemprop="name">  Hamlet
        </h1>
        <time itemprop="startDate" datetime="2026-11-14T19:30:00-08:00">Nov 14</time>
        <div itemprop="location" itemscope itemtype="https://schema.org/Place">
          <span itemprop="name">Playhouse</span>
          <div itemprop="geo" itemscope itemtype="https://schema.org/GeoCoordinates">
            <meta itemprop="latitude" content="47.6"><meta itemprop="longitude" content="-122.3">
          </div>
        </div>
        <img itemprop="image" src="/hamlet.jpg">
      </div>`,
    ),
    PAGE,
    offline(),
  );

  assertEquals(event.title, "Hamlet");
  assertEquals(iso(event.start_time_min), "2026-11-15T03:30:00.000Z");
  assertEquals(event.location_description, "Playhouse");
  assertEquals(event.rally_point_text, "POINT(-122.3 47.6)");
  assertEquals(event.banner_photo, "https://venue.example/hamlet.jpg");
});

Deno.test("reads an .ics link with a TZID", async () => {
  const ics = [
    "BEGIN:VCALENDAR",
    "BEGIN:VEVENT",
    "UID:1",
    "DTSTART;TZID=America/Chicago:20261114T190000",
    "DTEND;TZID=America/Chicago:20261114T220000",
    "SUMMARY:Ical Show",
    "LOCATION:The Venue\\, 1 Main St",
    "END:VEVENT",
    "END:VCALENDAR",
  ].join("\r\n");

  const fetched: string[] = [];
  const event = await extractFromHtml(
    page(
      '<meta property="og:title" content="Ical Show | The Venue">',
      '<a href="/events/big-show/?ical=1">Add to calendar</a>',
    ),
    PAGE,
    offline({
      fetchCalendar: (url) => {
        fetched.push(url.href);
        return Promise.resolve(ics);
      },
    }),
  );

  assertEquals(fetched, ["https://venue.example/events/big-show/?ical=1"]);
  assertEquals(event.title, "Ical Show");
  assertEquals(iso(event.start_time_min), "2026-11-15T01:00:00.000Z");
  assertEquals(iso(event.end_time), "2026-11-15T04:00:00.000Z");
  assertEquals(event.location_description, "The Venue, 1 Main St");
});

Deno.test("reads a Google Calendar link with ctz", async () => {
  const href =
    "https://calendar.google.com/calendar/render?action=TEMPLATE&amp;text=Gcal+Show&amp;dates=20261114T190000/20261114T210000&amp;ctz=Europe/Berlin&amp;location=Club";
  const event = await extractFromHtml(
    page("", `<a href="${href}">Google Calendar</a>`),
    PAGE,
    offline({ timezone: "America/New_York" }),
  );
  assertEquals(event.title, "Gcal Show");
  assertEquals(iso(event.start_time_min), "2026-11-14T18:00:00.000Z");
  assertEquals(event.location_description, "Club");
});

Deno.test("ignores calendar links for many different events", async () => {
  const link = (dates: string) =>
    `<a href="https://calendar.google.com/calendar/render?action=TEMPLATE&amp;text=x&amp;dates=${dates}">+</a>`;
  await assertRejects(() =>
    extractFromHtml(
      page(
        "",
        link("20261114T190000Z/20261114T200000Z") +
          link("20261120T190000Z/20261120T200000Z"),
      ),
      PAGE,
      offline(),
    )
  );
});

Deno.test("uses OG tags plus the LLM for an OG-only page", async () => {
  const calls: Array<Record<string, string>> = [];
  const event = await extractFromHtml(
    page(
      `<meta property="og:title" content="Museum Late &amp; Lights">
       <meta property="og:image" content="/late.jpg">
       <meta name="description" content="An evening in the galleries.">`,
      `<main><h1>Museum Late</h1><p>Friday, November 20 · 6–9pm</p>${FILLER}</main>`,
    ),
    PAGE,
    offline({
      timezone: "America/New_York",
      llm: stubLlm({
        title: "Museum Late",
        start_date_local: "2026-11-20T18:00",
        end_date_local: "2026-11-20T21:00",
        location_description: "Art Museum",
      }, calls),
    }),
  );

  assertEquals(calls[0], { title: "Museum Late & Lights" });
  assertEquals(event.title, "Museum Late");
  assertEquals(iso(event.start_time_min), "2026-11-20T23:00:00.000Z");
  assertEquals(iso(event.end_time), "2026-11-21T02:00:00.000Z");
  assertEquals(event.location_description, "Art Museum");
  assertEquals(event.banner_photo, "https://venue.example/late.jpg");
  assertEquals(event.notes, "An evening in the galleries.");
});

Deno.test("sends visible page text to the LLM without scripts or nav", async () => {
  let sentText = "";
  await extractFromHtml(
    page(
      "<style>.x{}</style>",
      `<nav>Home About</nav><div>Trivia night</div><br>Thursday 8pm<script>var x</script>${FILLER}<footer>©</footer>`,
    ),
    PAGE,
    offline({
      llm: (text) => {
        sentText = text;
        return stubLlm({ start_date_local: "2026-11-19T20:00" })(text, {}, "");
      },
    }),
  );
  assert(sentText.startsWith("Trivia night\n\nThursday 8pm\nDetails"));
  assert(!/Home About|var x|©/.test(sentText));
});

Deno.test("fails clearly when nothing describes an event", async () => {
  await assertRejects(
    () =>
      extractFromHtml(
        page("<title>About us</title>", FILLER),
        PAGE,
        offline({ llm: stubLlm({ is_event: false }) }),
      ),
    Error,
    "doesn't appear to describe a single event",
  );
  await assertRejects(
    () =>
      extractFromHtml(page("<title>About us</title>", FILLER), PAGE, offline()),
    Error,
    "Could not find the event's date and time",
  );
});
