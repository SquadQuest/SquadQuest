---
status: in-progress
depends: [v2-communities-core]
specs:
  - specs/behaviors/bring-friends-bridge.md
  - specs/api/ideas-activities.md
  - specs/api/communities.md
  - specs/screens/communities.md
issues: []
pr:
---

# Plan: v2 bring-friends bridge

## Scope

Bringing friends to a community event by posting a **friends-scoped idea that embeds the
event** — never sharing the public event onto the friends timeline. The public event stays
community-owned; what lands on My Friends is a private envelope whose thread is the logistics
room. Backend + client; styling deferred.

**In:** `createIdea` accepts `community_event_id` → a friends/squad-scoped activity with
`event_ref` (the event's title/time/place/community, read-only); activity serializer exposes
`event_ref`; **attendance coupling** — a brought-along "I'm in" counts in the event's
**anonymous** `going_count`, never the public face-pile; client "Bring friends" action on a
community event → composer pre-filled (event chip + destination picker) → posts the idea;
the friends/squad timeline + activity detail render the embedded-event chip.

**Out:** leader tooling; community-event threads; photos; SSE; auto "born confirmed" state
nuance (brought-along idea follows the normal lifecycle with the event providing time/place).

## Implements

`specs/behaviors/bring-friends-bridge.md` + the `community_event_id` path of
`specs/api/ideas-activities.md`; the "Bring friends" action of `specs/screens/communities.md`.

## Approach

- **Backend** (`server/`):
  - `createIdea`: allow `communityEventId` (currently rejected) — validate the event exists;
    store `activity.community_event_id`; idea is friends- or squad-scoped as chosen.
  - activity serializer: add `event_ref` (event id, title, time, recurrence, location,
    community {name,icon}) when `community_event_id` set.
  - **attendance coupling** in `CommunityService.events`/going_count: distinct attendees =
    direct RSVPs (going=true) ∪ profiles who responded `in` to any activity linked to the
    event. Never adds anyone to `public_going` without an explicit public RSVP. (Factor the
    count so this extends cleanly.)
  - a `GET /v1/community-events/:id` (single event) for the composer pre-fill, or reuse the
    event already in client state.
  - tests: brought-along idea has event_ref + is friends-scoped (never on a community feed);
    an "I'm in" responder is counted in going_count anonymously, absent from public_going.
- **Client** (`app/`):
  - "Bring friends" on a `CommunityEventCard` → switch to My Friends, open the composer
    pre-filled (event reference chip + activity type) with a destination picker (My Friends
    or a squad); `createIdea` with `community_event_id`.
  - Activity model + tiles/detail render the `event_ref` chip (read-only event context).

## Validation

- [ ] `bun run type-check` + `bun test` (brought-along idea: event_ref + friends-scoped +
      absent from community feed; "I'm in" → anonymous headcount +1, not public) green; CI.
- [ ] client `flutter analyze` + widget tests green; CI.
- [ ] (when machine free) MCP: Bring friends on an event → idea on My Friends w/ event chip;
      friend responds "I'm in" → event going_count +1, face-pile unchanged.

## Risks / unknowns

- The firewall invariant: the My-Friends composer only emits friends-scoped ideas; public
  exposure needs explicit community/public-RSVP action. Enforce server-side.
- going_count dedup across direct RSVPs + brought-along "in" responders (distinct profiles).
- event_ref must be read-only context; the brought-along activity is a separate record.

## Notes

(closeout)

## Follow-ups

(closeout)
