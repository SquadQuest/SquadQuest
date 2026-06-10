---
status: done
depends: [v2-communities-core]
specs:
  - specs/behaviors/bring-friends-bridge.md
  - specs/api/ideas-activities.md
  - specs/api/communities.md
  - specs/screens/communities.md
issues: []
pr: 424
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

- [x] `bun run type-check` + `bun test` — 2 tests (brought-along idea: event_ref +
      friends-scoped + public event unchanged; "I'm in" → anonymous headcount +1, face-pile
      unchanged); full suite 28/28; backend CI green (#423, merged).
- [x] client `flutter analyze` clean + 10 widget tests (composer prefilled-from-event chip);
      client CI on #424.
- [~] MCP visual walkthrough deferred (window-foreground conflict); backend invariants
      unit-tested.

## Risks / unknowns

- The firewall invariant: the My-Friends composer only emits friends-scoped ideas; public
  exposure needs explicit community/public-RSVP action. Enforce server-side.
- going_count dedup across direct RSVPs + brought-along "in" responders (distinct profiles).
- event_ref must be read-only context; the brought-along activity is a separate record.

## Notes

Two PRs: **#423** (backend — createIdea accepts community_event_id, activity serializer
event_ref, attendance coupling in CommunityService going_count) merged; **#424** (client —
Bring-friends action, composer pre-fill + event chip, event_ref on tiles/detail). The
firewall invariant holds end-to-end: the composer only emits friends-scoped ideas; a
brought-along "I'm in" adds at most an anonymous +1 to the event headcount, never identity.
Completes **communities** (core + bridge).

## Follow-ups

- **Deferred to plan:** the destination picker (My Friends vs a squad) in the bring-friends
  composer — currently posts to My Friends; community-event **threads** (the event_ref's
  thread); leader tooling; photos; SSE.
- **Deferred (UX):** a public RSVP / face-pile entry for a profile with no name (onboarding/
  welcome-wizard sets names; until then nameless public attendees are dropped from the
  face-pile though still counted).
