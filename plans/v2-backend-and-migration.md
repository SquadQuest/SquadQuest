---
status: planned
depends: [specops-foundation]
specs:
  - specs/architecture.md
  - specs/data-model.md
  - specs/api/conventions.md
  - specs/api/auth.md
  - specs/api/timeline.md
  - specs/api/ideas-activities.md
  - specs/api/communities.md
  - specs/api/messages.md
  - specs/behaviors/v1-migration.md
issues: []
pr:
---

# Plan: Stand up the v2 backend + v1 migration

## Scope

Build the fresh v2 backend per the foundation specs: the Fastify/Bun + Postgres service in
`server/`, the schema (migration-first), the versioned `/v1` API, auth, realtime, storage,
and the one-time bulk pre-migration + claim-on-login. Does **not** include wiring the
`lib/v2/` client off mock data (separate plan) or leader-side community tooling (separate
plan).

## Implements

`specs/architecture.md`, `specs/data-model.md`, all of `specs/api/`, and
`specs/behaviors/v1-migration.md`.

## Approach (to be detailed when picked up)

- Scaffold `server/` (Fastify + TS on Bun); migration tooling; `server/migrations/` for the
  v2 schema in `data-model.md`.
- Implement the `/v1` contract with the edge-adapter pattern (`server/src/contracts/`):
  domain model + per-build serializers; the build-header middleware + `min_supported_build`
  → 426 floor.
- Auth: phone-OTP (provider TBD, swappable) → JWT access/refresh; claim-on-login.
- Realtime: `GET /v1/stream` SSE + Postgres `LISTEN/NOTIFY` fan-out.
- Storage: signed-URL uploads to an object store (TBD, swappable).
- Bulk pre-migration job: read v1 Supabase read-only → write v2 profile/friendship/topic
  shells keyed by phone; idempotent; runnable repeatedly up to cutover.

## Validation

(to be filled when picked up — minimally: each `api/` endpoint conforms to its spec; the
build-header floor returns 426 below `min_supported_build`; the migration job is idempotent
and reproduces the accepted friend graph keyed by phone; a claimed login lands in a
populated friends timeline.)

## Risks / unknowns

- Provider/host/ORM picks (SMS, Postgres host, object store, query layer) are reversible
  implementation choices — decide at pickup, keep swappable.
- Realtime fan-out across multiple instances may need Redis pub/sub beyond `LISTEN/NOTIFY`.
- Cutover coordination with the app-store update + v1 web archive.

## Notes

## Follow-ups
