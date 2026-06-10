---
status: in-progress
depends: [v2-communities-core]
specs:
  - specs/api/communities.md
  - specs/screens/communities.md
issues: []
pr:
---

# Plan: v2 community leader tooling

## Scope

Make communities **self-serve** instead of seed-only: let users **create** a community (the
creator becomes its leader), **edit** it, and **post / edit / delete** its events — replacing
the `seed-communities.ts` stand-in. Backend + client; styling deferred.

**In:**

- Backend: `POST /v1/communities` (creator → `leader`), `PATCH /v1/communities/:id`,
  `POST /v1/communities/:id/events`, `PATCH`/`DELETE /v1/community-events/:id` — all
  leader-gated; `your_role` on the community item. No migration (the `community_role` enum
  - `community_membership.role` already exist).
- Client: a "New community" entry on Discover → create form; leader-only **Post event** on a
  community timeline + **edit community** title-bar action + event **edit/delete**; leader
  controls gated on `your_role:"leader"`.

**Out:** community **delete** (heavier — follower fan-out); leadership transfer / multi-leader
invite; activity-type picker on events (optional field, deferred); photo/icon upload (storage).

## Implements

`specs/api/communities.md` (leader tooling section + `your_role`) and the leader actions in
`specs/screens/communities.md`.

## Approach

- **Backend** (`server/`):
  - `CommunityService`: `isLeader(communityId, profileId)`; `create` (insert community +
    leader membership), `update` (leader-gated patch), `createEvent` / `updateEvent` /
    `deleteEvent` (leader-gated). Thread `yourRole` through `discover`/`CommunitySummary`.
  - routes `routes/v1/communities.ts` (extend) — `forbidden` via `errors.forbidden('forbidden', …)`.
  - serializer: add `your_role` to `serializeCommunity`. Reuse `serializeCommunityEvent`.
  - tests: create→leader, your_role surfaces, leader-only 403 on edit/post/delete, edits
    persist, delete cascades RSVPs.
- **Client** (`app/`):
  - `Community` model gains `yourRole`; `CommunityRepository` gains create/update +
    createEvent/updateEvent/deleteEvent; providers invalidate on mutate.
  - Discover screen: "New community" → `CreateCommunityScreen` (name/tagline/icon/color) →
    switch context to it.
  - Community timeline (`_CommunityBody`): leader sees a **Post event** affordance (→
    `CreateEventScreen`) instead of the follower banner; app-bar **edit community**; event
    cards get edit/delete (leader only).

## Validation

- [ ] `bun run type-check` + `bun test` (create makes leader + your_role; non-leader 403 on
      patch/post-event/patch-event/delete; edits persist; delete cascades RSVPs) green; CI.
- [ ] client `flutter analyze` + widget tests (create-community form posts; leader sees Post
      event, follower sees banner; post-event form) green; CI.
- [ ] (machine free) MCP: create a community → become leader → post an event → it appears on
      the timeline; a second account sees it as a plain follower (no leader controls).

## Risks / unknowns

- Leader vs follow interplay: leadership is a `role:"leader"` membership; **unfollow must not
  strip leadership** (guard `toggleFollow`).
- `your_role` plumbing through the existing `discover`/`myCommunities` aggregation without an
  extra query per community.
- Event edit/delete affordance placement on the card without crowding the RSVP gradient —
  keep it a leader-only overflow menu.

## Notes

(closeout)

## Follow-ups

(closeout)
