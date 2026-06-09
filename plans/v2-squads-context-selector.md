---
status: in-progress
depends: [v2-client-stage2-interactive-timeline]
specs:
  - specs/data-model.md
  - specs/screens/squads.md
  - specs/behaviors/context-selector.md
  - specs/api/ideas-activities.md
  - specs/api/timeline.md
issues: []
pr:
---

# Plan: v2 squads + context selector

## Scope

Closed, persistent named groups (squads) + the title-bar **context selector** that switches
the active context (My Friends ▸ a Squad) — timeline, title, audience indicator, and compose
destination all follow one source of truth. Squad-scoped ideas/activities reuse the existing
lifecycle. Backend + client; styling deferred.

**In:** squad + squad_membership; create squad / list my squads / add member; extend
`createIdea` to `scope=squad`; squad timeline (squad-scoped activities); client context
selector + active-context provider + squad timeline + create-squad flow.

**Out (later stages):** free-text squad messages + thread drawer (messages stage — the squad
timeline is activities-only for now, a subset of the spec's heterogeneous feed); polished
captain membership management (spec defers it); Communities/Discover entries in the selector
(communities stage — selector is built to extend to them).

## Implements

`specs/screens/squads.md` (activity slice), `specs/behaviors/context-selector.md`
(My Friends ▸ Squads), squad slice of `specs/data-model.md`, and the `scope=squad` path of
`specs/api/ideas-activities.md`.

## Approach

- **Backend** (`server/`):
  - schema `squad.ts`: `squad` (id, name, created_at), `squad_membership` (squad, profile,
    role ∈ captain|member, pk) + migration.
  - domain/routes: `POST /v1/squads` (creator → captain; optional initial member_ids, each
    must be an accepted friend), `GET /v1/squads` (my squads + role + member_count),
    `GET /v1/squads/:id` (detail + members, members-only), `POST /v1/squads/:id/members`
    (captain adds an accepted friend), `GET /v1/squads/:id/timeline` (squad-scoped activities,
    members-only, cursor-paginated).
  - extend `ActivityService.createIdea` to accept `scope=squad` + `squadId` (validate caller
    is a member); squad activities visible to squad members (new visibility branch).
  - squad serializer; tests.
- **Client** (`app/`):
  - `activeContextProvider` (sealed: `FriendsContext` | `SquadContext(id,name)`) — the single
    source of truth; timeline/title/compose read it.
  - context selector (tappable AppBar title → sheet: My Friends, my squads, New squad).
  - timeline screen branches on context → `friendsTimeline` or `squadTimeline(id)`; reuses the
    activity tiles.
  - composer: scope follows context (friends→all_friends; squad→scope=squad+squad_id);
    audience banner states the destination.
  - create-squad screen (name + multiselect from `GET /v1/friends`); SquadRepository.

## Validation

- [ ] migration applies; `bun run type-check` + `bun test` (squad create/list/add-member,
      member-gated timeline, scope=squad create, non-member 403) green; CI green.
- [ ] MCP end-to-end (two accounts): A creates a squad incl. B → both see it in the selector;
      A composes a squad idea → on the squad timeline for A & B, **absent** from My Friends;
      B responds/votes; A confirms. Screenshot the selector, squad timeline, compose-scoped.
- [ ] switching context updates title + feed + compose destination consistently.

## Risks / unknowns

- Visibility now has two branches (friends graph vs squad membership) — keep the predicate
  centralized and reused by reads + write authz.
- Active-context as one source of truth (title/feed/composer/destination never disagree).
- Squad timeline is activities-only this stage; wire the heterogeneous message feed in the
  messages stage without reshaping the context model.

## Notes

(closeout)

## Follow-ups

(closeout)
