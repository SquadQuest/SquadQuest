---
status: done
depends: []
specs:
  - specs/screens/squads.md
issues: []
pr: 473
---

# Plan: v2 squad members — view roster + captain adds members

> `specs/screens/squads.md` marked "Captain-only membership management is **deferred** (later
> plan)." This is that plan. The backend is already complete (`POST /v1/squads/:id/members`,
> captain-only + friend-gated + idempotent; `GET /v1/squads/:id` returns the roster) and the
> client repo already exposes `addMember`/`get` — the whole gap is the **client UI**: there is
> no screen to see who's in a squad or to add someone to an existing one.

## Scope

**In:**

- A **squad detail / members screen** at `/squads/:id`: shows the roster (avatar + name +
  captain badge). For the **captain**, an "Add members" affordance opens a friend picker
  (the create-squad pattern) limited to accepted friends **not already in the squad**; tapping
  adds via `addMember`. Members (non-captain) see the roster read-only.
- **Entry point:** a manage-members icon in the squad timeline's app bar (mirrors the existing
  community-edit icon), shown only when the active context is a squad.
- `squadDetailProvider` (family by squad id); invalidated after an add so the roster + the
  context selector's member count refresh.

**Out (still deferred):** removing members / leaving a squad; transferring or multiple
captains; renaming a squad; per-member roles beyond captain/member. The add path is
friend-gated by the existing backend rule (no inviting non-friends).

## Implements

- `specs/screens/squads.md` — replace the "deferred" line with the membership-management
  display rules + actions (captain adds friends; everyone sees the roster), and a new
  **Squad Members** screen section (route, data, display, actions, navigation).

## Approach

- **Client only** (backend + repo already done):
  - `SquadDetailScreen` (Consumer) at `/squads/:id` reading `squadDetailProvider(id)`.
  - Roster list; captain-only "Add members" → friend picker filtered to non-members →
    `squadRepositoryProvider.addMember` → invalidate `squadDetailProvider(id)` + `squadsProvider`.
  - App-bar `manageSquadButton` on the squad timeline → `context.push('/squads/$id')`.
  - Route wiring in `router.dart`.
- A widget test: captain sees the add affordance + a non-member friend is addable; the repo is
  called with the right ids. (Member-viewer read-only path asserted too if cheap.)

## Validation

- [x] `SquadDetailScreen` renders the roster from `GET /v1/squads/:id` with a captain badge.
- [x] Captain sees "Add members"; the picker excludes current members; tapping calls
      `addMember(squadId, profileId)` and the roster refreshes.
- [x] A non-captain member sees the roster read-only (no add affordance).
- [x] App-bar manage icon appears only for a squad context and routes to `/squads/:id`.
- [x] `flutter analyze` clean; `flutter test` green (39 tests, +2).

## Risks / unknowns

- The roster's captain/member role comes from `GET /v1/squads/:id` (`members[].role`), not the
  context — fine, the detail fetch is authoritative.
- Friend list vs member list both keyed by profile id — filter the picker by membership id set.

## Notes

Client-only: the backend (`POST /v1/squads/:id/members`, captain-only + friend-gated +
idempotent) and the repo's `addMember`/`get` already existed, so this was purely the missing
UI. The captain check reads the squad detail's `members[].role` against the signed-in
`currentProfile` id (the detail fetch is authoritative, not the context). Entry point is the
squad timeline's app-bar manage icon (user's call over the context selector). Add path reuses
the create-squad friend-picker pattern, filtered to non-members. Shipped in #473.

## Follow-ups

- **Deferred to plan** — removing members / leaving a squad, rename, captain transfer /
  multiple captains, per-member roles beyond captain/member. No plan filed yet; will spin one
  when membership editing is prioritized.
