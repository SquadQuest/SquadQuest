---
status: done
depends: [v2-repo-reset]
specs:
  - specs/api/conventions.md
  - specs/api/auth.md
  - specs/data-model.md
issues: []
pr: 407
---

# Plan: v2 backend Stage 1 — API foundation + auth + identity

## Scope

The foundational backend layer in `server/`: Postgres + Drizzle, the `/v1` conventions
middleware (build header → `426` floor, error envelope, JWT auth), the identity schema
(profile / friendship / topic / topic_subscription), the auth endpoints (OTP → JWT +
claim-on-login, dev-stub OTP), and `GET /v1/me` + `GET /v1/friends` to prove the authed
stack. First slice of the `v2-backend-and-migration` umbrella.

Out (later staged plans): the bulk v1→v2 pre-migration job; ideas/activities + timeline;
communities; squads/messages; SSE realtime; real SMS provider; storage/signed URLs.

## Implements

`specs/api/conventions.md`, `specs/api/auth.md`, and the identity slice of
`specs/data-model.md`.

## Approach

- **DB:** Drizzle ORM + drizzle-kit + `postgres` driver; `src/db` client plugin
  (`fastify.db`), `src/db/schema/*`, `drizzle.config.ts` → `migrations/`, `db:generate` /
  `db:migrate` scripts; local `docker-compose.yml`; `.env.example` (DATABASE_URL, JWT_SECRET,
  MIN_SUPPORTED_BUILD).
- **Conventions:** build-header parse + `426` floor hook; `sendError` + `ApiError` + global
  error handler emitting the spec envelope; JWT bearer auth preHandler. Wired into `/v1`.
- **Auth:** OTP store + `OtpProvider` interface + `ConsoleOtpProvider`; JWT issue/refresh/
  revoke; claim-on-login by normalized (E.164) phone (bind shell + set `claimed_at`, else
  create). `routes/v1/auth.ts`.
- **Identity reads:** `routes/v1/me.ts`, `routes/v1/friends.ts` + serializers in
  `src/contracts/`.
- **Tests:** Bun integration (otp→verify→/me→/friends) + 426 unit; wire into `pr-test`
  server job if a Postgres service is easy, else local-only (note the gap).

## Validation

- [x] `docker compose up -d && bun run db:migrate` applies; tables exist (6).
- [x] `bun run dev` boots; `bun run type-check` clean.
- [x] `POST /v1/auth/otp/request` → 200, code logged; `/otp/verify` → access+refresh +
      profile (`claimed_v1` correct).
- [x] authed `GET /v1/me` → profile; `GET /v1/friends` → accepted graph incl. an unclaimed
      "not on v2 yet" row (hand-seeded shell + friendship).
- [x] below-floor `X-SquadQuest-Client` → `426` with upgrade envelope; unauthed `/v1/me` →
      `401`.
- [x] `bun test` green (9 tests); `pr-test` server job → verified on PR #407.

## Risks / unknowns

- Drizzle + Bun + postgres.js / drizzle-kit edge cases — validate generate/migrate early.
- Postgres service in `pr-test` CI — straightforward on ubuntu; fall back to local-only +
  type-check in CI if flaky (flag it).
- OTP TTL/rate-limit kept simple in Stage 1.

## Notes

Shipped as PR #407 (5 commits: deps, schema+plumbing, conventions middleware, auth+identity,
tests+CI). Drizzle/Bun/postgres-js + drizzle-kit generate/migrate work cleanly (risk
cleared). Dev Postgres runs on host port **5532** (5432 is commonly taken by other projects).
Access tokens are JWT (15m); refresh tokens are opaque, hashed, rotating, DB-backed. CI: the
`pr-test` server job runs a `postgres:17` service + `db:migrate` + `bun test`.

Stage-1 simplifications (intentional): the client-build header is not hard-required when
absent (spec says required); phone normalization is US-centric best-effort (no
libphonenumber); OTP rate-limiting is minimal.

## Follow-ups

- **Deferred to plan:** bulk v1→v2 pre-migration job (reads v1 Supabase); ideas/activities +
  timeline; communities; squads/messages; SSE realtime; real SMS provider; storage/signed
  URLs. (Tracked under the `v2-backend-and-migration` umbrella.)
- **Tighten later:** hard-require the client-build header; libphonenumber-grade phone
  normalization; OTP request rate-limiting.
