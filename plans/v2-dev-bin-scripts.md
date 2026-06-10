---
status: done
depends: []
specs: []
issues: []
pr: 431
---

# Plan: v2 dev `bin/` scripts + worktree-isolated databases

## Scope

Replace the single fixed-name dev database (and the test suites clobbering it) with a `bin/`
task-runner over a `_common.sh` of shared shell helpers — adopting the jarvus-hq / transit-lake
pattern. The load-bearing idea is **worktree-aware database naming**: every context (main
checkout, each agent worktree, the test runner) gets its **own** database on one shared Postgres
container, so nothing clobbers anything. The recurring "tests wipe my demo data" artifact
becomes impossible by construction — the test runner just targets a derived `*_test` DB.

**In:**

- `bin/_common.sh` — shared helpers: `ensure_postgres` (start the shared container via
  `docker run` if absent), `sq_db_name` (worktree-aware: main → `squadquest_v2`, other worktree
  → `sq_<hash>`, test → `squadquest_test`), `sq_database_url`, `sq_psql`, port pickers.
- `bin/` scripts: **`setup`** (ensure pg + create DB + `bun install` + migrate), **`dev`**
  (server with auto-configured `DATABASE_URL`), **`reset-db`** (drop/recreate/migrate),
  **`db`** (run SQL / open psql), **`test`** (point bun test at the `*_test` DB, ensure+migrate
  first), **`cleanup`** (drop this worktree's DB).
- Tests target the test DB: a `server/bunfig.toml` preload (`test/setup.ts`) that defaults
  `DATABASE_URL` → `…/squadquest_test` (respecting an explicit env, so CI wins), ensures the DB
  exists + migrates once. Trim the duplicated `process.env.*` lines from the 9 `test/*.test.ts`.
- **Remove `server/docker-compose.yml`** — fully replaced by `bin/` (compose pins one fixed DB
  name + host port, which is exactly what defeats worktree isolation; see jarvus-hq commit
  3d41b61 "remove docker-compose, fully replaced by bin/setup").
- Docs: project `.claude/CLAUDE.md` (layout + a working-agreement for the `bin/` workflow and
  worktree isolation), `.env.example` (drop the "via docker-compose.yml" line; note `bin/`).

**Out:** snapshot / load-snapshot (those pull from a Cloud SQL **production** instance; v2 has
no prod yet — v1 lives on a separate branch/backend). CI changes (CI already uses an ephemeral
service-container DB + its own `DATABASE_URL`; the preload's `??=` defers to it — untouched).
Per-worktree client/app ports (server-only for now).

## Implements

Nothing in `specs/` — pure developer tooling. The architecture spec documents *what* the stack
is, not the local-dev lifecycle; the workflow + worktree-isolation convention is documented in
the project `CLAUDE.md` (a working agreement), not a product spec or principle.

## Approach

- **`_common.sh`** mirrors jarvus-hq's `_common.sh` but: container `squadquest-v2-postgres`,
  user/pw `squadquest`/`squadquest`, port `5532` (keep the existing default so current envs and
  CI's `5432` both keep working), and SquadQuest-prefixed helpers (`sq_*`). `sq_db_name`:
  main worktree → `squadquest_v2` (unchanged — existing dev data survives); other worktree →
  `sq_<md5(path)>`; the test runner forces `squadquest_test` via env.
- **Migrations** run with `drizzle-kit migrate` (reads `DATABASE_URL`) — SquadQuest has no
  `run-migrations.ts`; scripts `cd server` and run `bun run db:migrate` with the derived URL.
- **`bin/test`** sets `DATABASE_URL=…/squadquest_test`, ensures+migrates, then `cd server && bun
  test`. The `bunfig.toml` preload makes a bare `cd server && bun test` (no bin/) Do The Right
  Thing too, so neither path can hit the dev DB.
- **Monorepo shape:** `bin/` at repo root; scripts mostly target `server/`. `bin/dev` runs the
  server; the Flutter app keeps `cd app && flutter run` (documented), not wrapped here.
- Keep everything POSIX-bash + `set -euo pipefail`, status→stderr / machine env→stdout, matching
  the sibling repos so the convention reads identically across Jarvus projects.

## Validation

- [x] `bin/db "select 1"` works against the shared container; `bin/*` pass `bash -n`; server
      `tsc --noEmit` clean. (`bin/setup`/`bin/dev` exercised via their shared `_common.sh` path.)
- [x] `bin/test` **and** a bare `cd server && bun test` (no `DATABASE_URL`) run the suite
      **against `squadquest_test`** — proven by seeding a SENTINEL row in `squadquest_v2`,
      running both, and confirming it survived while `squadquest_test` was created separately.
      Full server suite **41/41** green.
- [x] `bin/cleanup` refuses to drop `squadquest_v2` without `--force`; `sq_db_name` derives a
      distinct `sq_<hash>` for a non-main worktree (worktree-aware naming, portable `sq_hash`).
- [x] `docker-compose.yml` removed; `.env.example` + project `CLAUDE.md` updated. CI
      (`pr-test.yml`) untouched — it sets `DATABASE_URL` explicitly, which the preload's `??=`
      defers to.

## Risks / unknowns

- **CI must stay untouched & green.** The preload defaults `DATABASE_URL` only with `??=`; CI
  sets it explicitly and migrates itself. Verify the preload no-ops when the env is provided.
- **Existing dev data:** main worktree keeps targeting `squadquest_v2`, so current local data
  survives the switch. Only the *test* target changes (to `squadquest_test`).
- **`md5sum` vs `md5`** (Linux vs macOS) in `sq_db_name` — the sibling repos use `md5sum`; on
  macOS use `md5 -q` or shell out portably. Get the hash helper cross-platform.
- **psql availability:** `sq_psql` execs `psql` *inside* the container (`docker exec`), so no host
  psql needed — keep that approach.
- Bun preload + `drizzle-kit migrate` ordering: ensure the DB exists before migrate (preload
  creates it via a transient postgres-js connection to the `postgres` maintenance DB).

## Notes

Adopted the jarvus-hq/transit-lake `bin/` pattern (PR #431): `bin/_common.sh` (shared pg
container `squadquest-v2-postgres` on 5532, `sq_db_name` worktree-aware naming, `sq_psql`,
ensure/recreate/migrate helpers) + `bin/{setup,dev,reset-db,db,test,cleanup}`. Tests target a
dedicated `squadquest_test` DB via a bun preload (`server/bunfig.toml` → `test/setup.ts`) that
defaults `DATABASE_URL` with `??=` (CI's explicit URL wins), creates the DB if missing, and
migrates with drizzle-orm's programmatic migrator. The 9 test files lost their duplicated env
preamble (centralized); `auth.test.ts` keeps only its `MIN_SUPPORTED_BUILD='500'` override.
Removed `server/docker-compose.yml` (compose pins one fixed DB+port — defeats worktree
isolation; same reasoning as jarvus-hq commit 3d41b61).

**Why `bin/` over docker-compose** (the user's prompt): compose can't host a separate database
per worktree on one container, which is the whole point — main → `squadquest_v2` (dev data
preserved), each agent worktree → `sq_<hash>`, tests → `squadquest_test`. Proven: a sentinel
row seeded in dev survived a full test run.

**Migrations:** scripts use `drizzle-kit migrate` (the `db:migrate` script); the in-process
preload uses `drizzle-orm/postgres-js/migrator` (`migrationsFolder: './migrations'`). Both read
the same `migrations/` output.

## Follow-ups

- **Residual footgun (accepted, documented):** if a dev creates `server/.env` with
  `DATABASE_URL=…squadquest_v2`, bun auto-loads it and a **bare** `bun test` would defer to it
  (the preload uses `??=`). `bin/test` is immune (it `export`s the test URL, which beats `.env`)
  and CI is immune (explicit env). The safe ergonomic path is `bin/test`; not worth a guard
  that keys on DB name (CI's throwaway DB is literally named `squadquest_v2`). Documented in
  `CLAUDE.md`.
- **Deferred (not adopted):** `snapshot`/`load-snapshot` (no v2 prod yet — v1 is a separate
  branch/backend); per-worktree client/app ports and a `bin/dev` that also runs Flutter; a
  `setup`-prints-env contract for an orchestrator. Add if/when multi-worktree server runs or a
  prod snapshot source exists.
- **Tracked as:** if we later want CI to use `bin/test` too, CI would need Docker-in-the-runner
  or a tweak so `_common.sh` can target an external service container — out of scope here.
