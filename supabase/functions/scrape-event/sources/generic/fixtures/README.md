# Real-world event pages

Regression cases for the generic fallback scraper, captured from live pages on
2026-10-25. `wild_test.ts` replays each one offline: `<slug>.html` is the
trimmed page, and `<slug>.json` holds its URL, what the page shows, the recorded
calendar files, timezone lookups and LLM answer, and the expected result.

To add a case:

```bash
deno run -A --unstable-temporal --env=supabase/functions/.env \
  supabase/functions/scrape-event/sources/generic/fixtures/capture.ts <slug> <url>
```

Review the snapshot it prints before committing. After an intended behavior
change, `capture.ts --rebaseline <slug>...` recomputes expected results from the
recorded data without refetching; review the diff.

## 1. JSON-LD Event inside @graph

- `1-bibliocommons-toastmasters`:
  https://chipublib.bibliocommons.com/v2/events/6a1a0a334dc267647dab13f3
- `1-brickstore-fourth-tuesday`:
  https://www.brickstoremuseum.org/calendar/fourth-tuesday-6/
- `1-columbia-seminars-autumn-term-ends`:
  https://universityseminars.columbia.edu/event/autumn-term-ends-3/

## 2. Event subtypes and multi-event pages

- `2-dice-cause-halloween`:
  https://dice.fm/event/nv6y59-the-cause-x-2026-halloween-festival-31st-oct-the-cause-at-60-dock-road-london-tickets
- `2-eventticketscenter-dice-sf`:
  https://www.eventticketscenter.com/dice-san-francisco-tickets/1415233/e
- `2-outsavvy-rvt-panto`:
  https://www.outsavvy.com/event/37887/pulled-the-2026-rvt-panto
- `2-todaytix-book-of-mormon`:
  https://www.todaytix.com/nyc/shows/127-the-book-of-mormon
- `2-wegottickets-bowie-special`: https://wegottickets.com/event/688941

## 3. Unusual script tag attributes

- `3-luma-leaddev-sf`: https://luma.com/elfrjrc8
- `3-meetup-pi-model-harness`:
  https://www.meetup.com/deep-learning-rtp/events/316369173/
- `3-okhistory-photos-with-santa`:
  https://www.okhistory.org/calendar/event/photos-with-santa/2026-12-12/

## 5. Date-only starts / many instances

- `5-cornell-america-at-250`:
  https://events.cornell.edu/event/america-at-250-focus-on-george-washington

## 6. Messy locations and offsets

- `6-cornell-atkinson-symposium`:
  https://events.cornell.edu/event/2026-cornell-atkinson-graduate-research-symposium
- `6-humanitix-yec`: https://events.humanitix.com/yec-2026
- `6-meetup-online-myth-adventures`:
  https://www.meetup.com/comics-and-animation-meetup/events/317031060/
- `6-squarespace-northaven-kids-night`:
  https://www.northaven.org/events/kids-night-out-5

## 7. Microdata only

- `7-dothebay-mountain-goats`:
  https://dothebay.com/events/2026/11/15/the-mountain-goats-night-one-openers-tickets
- `7-frisco-civicplus-art-reception`:
  https://www.friscotexas.gov/Calendar.aspx?EID=7817
- `7-growthzone-jerry-pinkney`:
  https://business.amherstarea.com/events/details/the-art-of-jerry-pinkney-10-31-2026-25057

## 8. .ics and calendar links

- `8-930club-amble`: https://www.930.com/e/amble/
- `8-idaho-doi-medicare-workshop`:
  https://doi.idaho.gov/event/medicare-workshop-26/
- `8-mpi-kc-palm-tree-club`:
  https://www.mpi.org/chapters/kansas-city/education-events/event/2026/08/19/default-calendar/august-monthly-meetup---palm-tree-club
- `8-nwciowa-rocket-league`:
  https://www.nwciowa.edu/calendar/events/27227/rocket-league-vs-arkansas

## 9. OpenGraph/meta only (LLM)

- `9-lam-unisg-autumn-event`:
  https://lam.unisg.ch/en/event/lucerne-transport-museum-visit-to-the-planetarium
- `9-mainstreetumc-harvest-feast`:
  https://mainstreetumc.org/events/harvest-feast-nov-6/
- `9-salemstate-corners-grove`:
  https://www.salemstate.edu/calendar/corners-grove-kaela-mei-shing-garvin-nov-20-2026

## 10. No metadata (LLM)

- `10-howardcc-our-town`:
  https://howardcc.edu/discover/arts-culture/horowitz-visual-and-performing-arts-center/hcc-theatre/our-town.php
- `10-searchandcare-yorkville-ball`:
  https://www.searchandcare.org/event/yorkvilleball/
- `10-wlu-almost-maine`: https://my.wlu.edu/lenfest-center/almost-maine

## 11. Blocked or JavaScript-only (should fail cleanly)

- `11-broadway-com-client-challenge`:
  https://www.broadway.com/shows/play-goes-wrong-beginning-february-11-2019/event/21764050/11-30-2026/1900/
- `11-ckord-spa-shell`:
  https://app.ckord.com/performances/0eabb393-7058-4fcb-8eae-c8206e5bfbce
- `11-shotgun-vercel-checkpoint`: https://shotgun.live/en/cities/paris
- `11-skiddle-aws-waf`:
  https://www.skiddle.com/whats-on/Harrow/Boxpark-Wembley/Country-Club---Indoor-Country-Music-Festival---London/42619137/
- `11-sofar-spa-shell`: https://www.sofarsounds.com/cities/london
- `11-tickpick-cloudflare-403`:
  https://www.tickpick.com/buy-six60-tickets-exit-in-11-15-26-8pm/8152360/
- `11-umich-cloudflare-challenge`: https://events.umich.edu/week/2026-11-04
