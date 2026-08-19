# Migrations & seeds — the project-specific wiring

`app_migrate()` in `_common.sh` is the one helper that's almost always
project-specific. Everything else in the pattern is migration-tool-agnostic; this
is where you adapt.

## Migrations

Set `app_migrate()` to however the project applies migrations. Three shapes seen
across real projects:

- **A package script** (simplest — reuse what `package.json` already defines):

  ```bash
  app_migrate() {
    local url="$1"
    echo "Running migrations..." >&2
    (cd "$(app_server_dir)" && DATABASE_URL="$url" bun run db:migrate) >&2
  }
  ```

  e.g. `db:migrate` → `drizzle-kit migrate`. The drizzle config reads
  `DATABASE_URL` from env, so passing it through is enough.

- **A migration runner script** (when there's a dedicated entrypoint):

  ```bash
  app_migrate() {
    local url="$1"
    echo "Running migrations..." >&2
    DATABASE_URL="$url" bun run "$(app_server_dir)/src/db/run-migrations.ts" >&2
  }
  ```

- **A self-migrating app** — the app runs its own programmatic migration runner
  at boot: fresh-bootstrap when the DB is empty, baseline detection on an
  existing schema, then additive incremental migrations. The division of labor
  flips: **`bin/dev` needs no migrate step** (starting the app *is* migrating),
  and `bin/setup` + the test preload call the app's own runner instead of
  shelling out to a migration CLI. For `bin/setup` that means a thin entrypoint
  into the runner:

  ```bash
  app_migrate() {
    local url="$1"
    echo "Running migrations..." >&2
    (cd "$(app_server_dir)" && DATABASE_URL="$url" \
      uv run python -c 'from app.db.migrations import run; run()') >&2
  }
  ```

  Keep the `app_migrate` call in `setup`/`reset-db` anyway — it makes the DB
  queryable via `bin/db` before first boot, and a skipped migrate is
  self-healing here (the next app start covers it).

The **test preload** migrates in-process instead of shelling out (it's already in
the app's language and wants no Docker dependency) — drizzle-orm's programmatic
`migrate(drizzle(sql), { migrationsFolder })`, or for a self-migrating app,
importing and awaiting the app's own runner. Both read the same migration set as
`app_migrate`; they're two callers of one migration system, not two systems.

Non-bun stacks: `alembic upgrade head` (Python), `rails db:migrate`,
`migrate -path … up` (golang-migrate), etc. — same idea, swap the command.

### The `/docker-entrypoint-initdb.d` mount — recognize it, then retire it

A common pre-`bin/` idiom you'll meet during adoption: the compose file mounts
the migrations directory into the Postgres container at
`/docker-entrypoint-initdb.d`, so the official image applies the `.sql` files
itself. Its trap: those scripts run **only on the first boot of an empty
volume**. Add a migration later and every existing volume silently never sees
it — the "migration system" stops migrating the moment anyone has data. It also
couples schema application to container creation, which the shared-container
pattern deliberately decouples.

Retirement path: point `app_migrate` at the same migration files via a real
runner (any of the three shapes above), drop the mount from the container
definition, and let `bin/setup`/`bin/reset-db` own schema application. Existing
volumes don't need recreating — the runner brings them forward.

## Seeds (optional) — three postures

How you populate a fresh dev DB is a project choice. Three postures seen across real
repos:

1. **Synthetic seeds** — hand-authored idempotent `seed*.sql`
   (`INSERT … ON CONFLICT DO NOTHING`) run on a fresh non-snapshot DB, plus an
   optional local `.scratch/extra-seed.sql` for personal data. Right when the curated
   dataset *is* the product (e.g. a demo app).
2. **Snapshot-as-seed** — no hand-written fixtures at all; `bin/load-snapshot`
   (default → latest prod) *is* the seed. Right when real prod data exists; often the
   only synthetic thing left is a dev auth token/secret applied at runtime, not at
   setup. See **`references/snapshots.md`**. This is the guardrail's ideal — nothing
   to maintain.
3. **Empty + per-suite fixtures** — `setup` leaves the DB empty (just migrated) and
   tests build their own fixtures per suite. Right when there's no meaningful shared
   dev dataset (and prod data is PII you wouldn't pull to a laptop).

Decision rule: **do you have meaningful prod data to pull?** Yes → snapshot-as-seed.
No, but the dataset is the deliverable → synthetic. Neither → empty + fixtures.

Whichever you pick: keep seeds **idempotent**, **don't seed when loading a snapshot**
(it already has data), and **don't seed the test DB** (suites own their fixtures). To
wire posture 1, uncomment the seed lines in `setup`/`reset-db`.

## A note on what NOT to put here

Resist baking application-specific data setup into these scripts beyond a thin
seed hook. The scripts manage the *database lifecycle*; rich fixture/demo data is
the app's concern and tends to churn. Keep the boundary clean so the scripts stay
portable across projects.
