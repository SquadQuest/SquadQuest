---
status: done
depends: []
specs:
  - specs/README.md
  - specs/principles.md
  - specs/architecture.md
  - specs/data-model.md
  - specs/api/conventions.md
  - specs/behaviors/v1-migration.md
issues: []
pr: 405
---

# Plan: Adopt SpecOps + author the v2 foundation specs

## Scope

Stand up spec-driven development in the repo and author the load-bearing v2 specs that are
already decided. Specs + scaffolding only — **no** backend stood up, **no** migration code,
**no** v2 client wiring to real data (those are downstream plans).

## Implements

Creates the `specs/` tree (principles, architecture, data-model; `api/` conventions + first
endpoints: auth, timeline, ideas-activities, communities, messages; `screens/`:
friends-timeline, communities, squads, welcome-wizard; `behaviors/`: v1-migration,
ideas-activities-lifecycle, response-system, audience-visibility, bring-friends-bridge,
context-selector, thread-drawer). Plus `plans/` + the SpecOps CLI session hook + the
spec-drift-auditor agent/command + CLAUDE.md sections.

## Approach

Anchored on the resolved transition + backend decisions:

- **Fresh v2 backend** — custom Fastify/Bun + Postgres (not Supabase); v1 archived as a
  read-only web build.
- **Carry** profiles + friend graph + topics via **bulk pre-migration, claim-on-login**,
  keyed by **phone**; **archive** events.
- **Versioned API**: client never touches the schema; `/v1` major + additive/supersede +
  client-build header + `min_supported_build`/426 floor.
Port the existing `docs/v2-specs/README.md` narrative into the structured specs; leave that
file as a pointer to `specs/`.

## Validation

- [x] `specs/` tree present; `specs/README.md` indexes it.
- [x] Every screen/behavior/api spec's `## Principles` links resolve to real
      `principles.md` anchors.
- [x] `<specops>/scripts/specops` prints the dashboard listing this plan + the v2-backend plan.
- [x] `<specops>/scripts/specops hook status` shows the project hook installed; `dag` renders.
- [x] `/audit-spec-drift` command present; `.claude/agents/spec-drift-auditor.md` resolves.
- [x] `docs/v2-specs/README.md` points to `specs/` (single source of truth).
- [x] CLAUDE.md has SpecOps + Plans sections.

## Risks / unknowns

- Hook writes `.claude/settings.json` — must merge, not clobber existing project settings.
- Mock UI is still iterating; per-screen specs kept at "decided" altitude to avoid rot.

## Notes

All validation criteria pass; the SessionStart hook merged into `.claude/settings.json`
alongside the existing PostToolUse formatter hook (did not clobber). Backend stack settled
during planning: **custom Fastify/Bun + Postgres, not Supabase** (client binds to a
versioned `/v1` API, never the schema) — captured in `architecture.md` + `api/conventions.md`.
The API contract was specced in this pass (scope expanded by the user to include `specs/api/`).
`flutter analyze lib/v2/` unchanged (no Dart touched).

## Follow-ups

- **Deferred to plan:** `v2-backend-and-migration` — stand up `server/`, the schema, the
  `/v1` contract, auth/realtime/storage, and the bulk pre-migration + claim-on-login.
- **Deferred to plan (not yet filed):** wire `lib/v2/` screens off mock data onto the real
  API client; onboarding + friend-connection/QR flow; community leader-side tooling.

(closeout)
