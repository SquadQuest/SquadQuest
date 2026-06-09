---
status: in-progress
depends: [v2-messages-and-threads]
specs:
  - specs/api/communities.md
  - specs/screens/communities.md
  - specs/behaviors/context-selector.md
  - specs/data-model.md
issues: []
pr:
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

- [ ] migration applies; `bun run type-check` + `bun test` (discover + you_follow; follow
      toggles follower_count; events list w/ counts; RSVP gradient — going-only anonymous,
      public implies going, going:false clears, public never a side effect) green; CI green.
- [ ] client `flutter analyze` + widget tests green; CI green.
- [ ] (when machine free) MCP: follow a community → it appears in the selector; open it →
      event cards; RSVP Going (count +1, not in face-pile) → Show name (joins face-pile).

## Risks / unknowns

- The Going/public split is load-bearing (privacy) — `public` must never be set implicitly.
- going_count is distinct attendees; brought-along coupling is added with the bridge plan —
  keep the count query factored so the bridge can extend it.
- Seeding communities/events without leader tooling — a dev seed, clearly not production.

## Notes

(closeout)

## Follow-ups

(closeout)
