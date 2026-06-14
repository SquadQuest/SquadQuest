---
status: done
depends: []
specs:
  - specs/screens/communities.md
  - specs/screens/wants.md
  - specs/behaviors/ideas-activities-lifecycle.md
issues: []
pr: 474
---

# Plan: v2 journey gap-fixes — wire spec'd affordances the client was missing

> Came out of a **user-journey audit** (specs vs. implementation, all journeys fanned out in
> parallel). The pattern this session keeps surfacing: a behavior is fully specified and the
> backend + repo support it, but the **client affordance was never wired** — the same shape as
> the squad-members gap (#473). The specs were already correct, so this is pure spec↔code
> conformance, not a spec change. Three concrete dead-ends fixed.

## Scope

**In — three backend-ready affordances the UI was missing:**

1. **Community event → thread** (HIGH). Tapping an event card did nothing; it now opens the
   event's thread. Backend `GET/POST /v1/threads/community_event/:id/messages`, the
   `/thread/:targetType/:targetId` route, and `event.thread_count` all already existed.
2. **Manage invites on an existing want** (MEDIUM). The want menu was promote/edit/delete only;
   to change who's invited you had to delete + recreate. Added a "Manage invites" sheet
   (add/remove accepted friends) calling the already-present `invite`/`uninvite`.
3. **Suggest an option** (MEDIUM). When an idea has `allow_suggestions`, there was no way to add
   a time/place. Added "Suggest a time/place" affordances (incl. when there are no options yet)
   calling the already-present `addOption`.

**Out (correctly belongs elsewhere, flagged by the audit but not fixed here):**

- Thread-as-a-right-side-**drawer** overlay, a persistent **vote bar inside** the thread, inline
  response controls on **timeline tiles**, collapsing response chips — these are the
  **`v2-styling-pass`** re-port (presentation/UX architecture). The functionality already works
  on the activity detail screen; turning it into the mock's drawer is the styling effort.
- Welcome-wizard intro **PageView** pages + an **Interests** bottom-nav tab — onboarding scope.
- v1 **topic-subscription** carry in the migration — migration scope (needs verifying against
  `v1-migration.md`; not a client gap).

## Implements

No spec changes — `specs/screens/communities.md` ("Open an event → thread"),
`specs/screens/wants.md` ("Invite / remove friends on your want"), and
`specs/behaviors/ideas-activities-lifecycle.md` (suggest when `allow_suggestions`) **already
specified** all three. Code was brought into conformance.

## Approach

Client-only:

- `community_event_card.dart` — wrap the card body in an `InkWell` → `push('/thread/community_event/:id')`; RSVP chips + leader menu keep their own gestures.
- `wants_screen.dart` — "Manage invites" menu item → `_ManageInvitesSheet` (checkbox list of friends, seeded from current invitees, each toggle calls invite/uninvite + invalidates `ownWantsProvider`).
- `activity_detail_screen.dart` — render When/Where when options exist **or** suggestions are open; add "Suggest a time/place" → label dialog → `addOption`.

## Validation

- [x] Tapping a community event card routes to `/thread/community_event/:id` (widget test).
- [x] Want "Manage invites" adds a non-invitee (invite) and removes an invitee (uninvite) (widget test).
- [x] "Suggest a time/place" shows when `allow_suggestions` (even with no options) and calls `addOption` (widget test).
- [x] `flutter analyze` clean; `flutter test` green (42 tests, +3).

## Risks / unknowns

- The event-card InkWell nests buttons (RSVP chips, menu) — Material handles nested gesture
  arenas, verified the chips still win their own taps (their `onSelected`/`onPressed` fire first).

## Notes

Found by fanning out parallel journey-audit subagents (onboarding+friends / ideas+thread+wants /
communities+squads). One subagent falsely claimed captain-confirm/vote/response weren't wired on
the activity detail screen — they are; verified before acting (don't over-trust the fan-out).
The genuinely-missing items were these three dead-ends. Shipped in #474.

## Follow-ups

- **Deferred to plan** — the drawer-ification of threads + inline timeline-tile responses +
  vote-bar-in-thread belong to `v2-styling-pass` (the mock re-port). Welcome intro pages +
  Interests tab are onboarding scope; v1 topic-subscription carry is migration scope — none
  filed as their own plans yet.
