---
status: done
depends: [v2-messages-and-threads]
specs:
  - specs/api/communities.md
  - specs/screens/communities.md
  - specs/behaviors/context-selector.md
  - specs/data-model.md
issues: []
pr: 422
---

# Plan: v2 communities — core (discover / follow / events / RSVP)

## Scope

The follower-facing community surface: discover communities, follow/unfollow, view a
community's born-confirmed recurring events, and RSVP with the **visibility gradient**
(anonymous `going` vs opt-in `public` face-pile). Backend + client; styling deferred.

**In:** community + community_membership + community_event + community_event_rsvp; GET
/v1/communities (discover + you_follow), PUT follow, GET /v1/communities/:id/events, PUT
/v1/community-events/:id/rsvp (going/public gradient); dev seed of communities+events
(leader tooling deferred); client Communities/Discover in the context selector + community
timeline (event cards: headcount + opt-in face-pile + Going/Show-name toggles) + follow.

**Out:** **bring-friends bridge** (its own next plan — `createIdea` w/ community_event_id,
event_ref serialization, attendance coupling, composer pre-fill); **leader tooling**
(create/edit communities + post/schedule events — deferred per spec); community_event
**threads** (thread_count surfaced but reads/replies deferred); photos; SSE.

## Implements

`specs/api/communities.md` (read/follow/RSVP), `specs/screens/communities.md`, the
community entries of `specs/behaviors/context-selector.md`, and the community slice of
`specs/data-model.md`.

## Approach

- **Backend** (`server/`):
  - schema `community.ts`: community (id, name, tagline, icon, color), community_membership
    (community, profile, role leader|follower), community_event (id, community, title,
    activity_type→topic, time, recurrence, location, created_at), community_event_rsvp
    (event, profile, going, public) + migration.
  - `CommunityService`: list/discover (+ you_follow, follower_count), toggleFollow, events
    (+ going_count, public_going face-pile, your_rsvp, thread_count), setRsvp (gradient:
    public implies going; going:false clears both; public never a side effect).
  - serializer; routes; a dev seed script (`scripts/seed-communities`) since leaders can't
    create yet.
  - tests.
- **Client** (`app/`):
  - Community + CommunityEvent models; CommunityRepository (list, follow, events, rsvp);
    providers; the context selector gains **Communities** (followed) + **Discover**.
  - community timeline (event cards: author = community + recurrence, anonymous headcount,
    opt-in face-pile, **Going** + **Show name** toggles, follow banner — no composer).
  - a Discover screen (search + follow).

## Validation

- [x] migration applies; `bun run type-check` + `bun test` (discover + you_follow; follow
      toggles follower_count; full RSVP gradient — going-only anonymous, public implies going,
      going:false clears, public never a side effect) — 2 tests, full suite 26/26; backend CI
      green (#421, merged).
- [x] client `flutter analyze` clean + 9 widget tests (community card render); client CI on #422.
- [~] MCP visual walkthrough deferred (window-foreground conflict); dev DB seeded with the 3
      Philly communities + events for live exploration.

## Risks / unknowns

- The Going/public split is load-bearing (privacy) — `public` must never be set implicitly.
- going_count is distinct attendees; brought-along coupling is added with the bridge plan —
  keep the count query factored so the bridge can extend it.
- Seeding communities/events without leader tooling — a dev seed, clearly not production.

## Notes

Two PRs: **#421** (backend — schema/migration 0004, CommunityService with the RSVP visibility
gradient, discover/follow/events/rsvp routes, dev seed-communities script, 2 tests) merged;
**#422** (client — Community/CommunityEvent models, CommunityRepository, CommunityContext + the
four-section context selector, community event cards with headcount/face-pile/RSVP toggles,
Discover screen). Leader tooling stood in via the seed script.

## Follow-ups

- **Deferred to plan (next):** **bring-friends bridge** — `createIdea` with
  `community_event_id` (event_ref serialization), the composer pre-fill from an event +
  destination picker, and attendance coupling (a brought-along "I'm in" → the event's
  *anonymous* headcount, never the public face-pile). Keep the going_count query factored to
  extend it.
- **Deferred to plan:** leader tooling (create/edit communities + post/schedule events);
  community-event **threads** (count surfaced; reads/replies need community_event added to the
  message thread-target visibility); photos; SSE.
- **Deferred (visual QA):** MCP walkthrough of follow → RSVP gradient when the machine is free.
