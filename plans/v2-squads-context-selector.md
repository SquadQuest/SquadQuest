---
status: done
depends: [v2-client-stage2-interactive-timeline]
specs:
  - specs/data-model.md
  - specs/screens/squads.md
  - specs/behaviors/context-selector.md
  - specs/api/ideas-activities.md
  - specs/api/timeline.md
issues: []
pr: 417
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

- [x] migration applies; `bun run type-check` + `bun test` (squad create/list/add-member,
      member-gated timeline, scope=squad create, non-member 403) — 4 squad tests, full suite
      21/21; backend CI green (#416, merged).
- [x] client `flutter analyze` clean + 6 widget tests (create-squad picker + updated
      timeline/detail fakes); client CI on #417.
- [~] MCP end-to-end screenshot walkthrough (two accounts): **deferred** — driving text entry
      needs the app window foregrounded, impractical while the machine is in use. The
      member-only / never-on-friends visibility is unit-tested (#416) and the login→compose→
      respond→vote→confirm driver loop was demonstrated in the prior stage; only the visual
      squad walkthrough is outstanding.
- [x] switching context updates title + feed + compose destination from one source of truth
      (`activeContextProvider`) — implemented; verified structurally, not screenshot-demoed.

## Risks / unknowns

- Visibility now has two branches (friends graph vs squad membership) — keep the predicate
  centralized and reused by reads + write authz.
- Active-context as one source of truth (title/feed/composer/destination never disagree).
- Squad timeline is activities-only this stage; wire the heterogeneous message feed in the
  messages stage without reshaping the context model.

## Notes

Shipped as two PRs: **#416** (backend — schema/migration 0002, SquadService, routes,
`scope=squad` in createIdea + squad-membership visibility branch + squadTimeline, 4 tests)
merged to develop; **#417** (client — active-context provider, context selector, squad
timeline, scoped composer + destination banner, create-squad flow, 6 widget tests). One
visibility predicate now spans friends-graph and squad-membership, reused by reads + write
authz. `activity.squad_id` stays a plain uuid (no FK) — membership integrity enforced in the
domain. Activities-only squad timeline this stage.

## Follow-ups

- **Deferred (visual QA):** run the two-account MCP screenshot walkthrough of the squad flow
  when the machine is free to hold the app window in foreground.
- **Deferred to plan:** free-text squad messages + thread drawer (messages stage — fills out
  the heterogeneous squad feed); Communities/Discover entries in the context selector
  (communities stage); polished captain membership management; people-targeted audience +
  suggest-option client UI.
- **Tracked as (skill):** the desktop window-focus constraint for MCP text entry is already
  documented in the mobile-flutter skill's mcp-driving reference.
