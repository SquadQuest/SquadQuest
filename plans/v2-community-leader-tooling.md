---
status: done
depends: [v2-communities-core]
specs:
  - specs/api/communities.md
  - specs/screens/communities.md
issues: []
pr: 429
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

- [x] `bun run type-check` + `bun test` (create makes leader + your_role surfaces; non-leader
      403 on patch/post-event/patch-event/delete; edits persist; delete cascades RSVPs;
      leader-unfollow no-op) green — suite **41/41**; CI green on #428.
- [x] client `flutter analyze` + widget tests (create-community form posts + blank rejected;
      post-event form posts; event card leader-menu only for a leader) green — suite **20**;
      CI green on #429.
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

Two PRs: **#428** (backend — `POST`/`PATCH /v1/communities`, `POST /v1/communities/:id/events`,
`PATCH`/`DELETE /v1/community-events/:id`, all leader-gated; `isLeader`/`assertLeader`;
`your_role` on the community item; unfollow never strips leadership) and **#429** (client —
"New community" FAB + create/edit form; leader-gated Post-event affordance, app-bar edit-
community, per-card edit/cancel menu; `Community.yourRole`/`isLeader`, repo create/update +
event create/update/delete, `activeCommunityProvider`). Both CI-green and merged. Communities
are now **self-serve** — the `seed-communities.ts` stand-in is no longer the only way to get
communities/events (kept for convenient demo data).

Decisions worth noting: **leadership is a `community_membership` with `role:"leader"`** (no
separate table) — it implies following, and **unfollow never strips it** (guarded in
`toggleFollow`). `your_role` is surfaced as `"leader" | null` (a plain follower is just
`you_follow:true`). Event `time`/`recurrence`/`location` stay free-text display strings (no
date picker yet). The activity-type picker on events was deferred (optional field).

The third validation item (live MCP walkthrough) is pending a free machine — tracked below.

## Follow-ups

- **Deferred (UX/styling):** event date/time picker (currently free-text); activity-type
  picker on events; community **color** picker + icon/photo upload (needs storage); a richer
  community-detail/leader-dashboard screen.
- **Deferred to plan / future:** community **delete** (follower fan-out); **leadership
  transfer / co-leader invite** (multi-leader); per-event **threads** surfaced from the card.
- **Verification owed:** live MCP walkthrough (create community → leader → post event →
  appears on timeline; second account sees a plain follower view) + screenshots, when the
  machine is free.
