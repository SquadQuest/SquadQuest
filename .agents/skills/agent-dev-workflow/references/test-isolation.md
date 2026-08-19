# Test isolation — never let tests clobber dev data

The single highest-value payoff of this pattern: **tests run against their own
database (`app_test`), so a test suite's `truncate`/reset can never wipe the dev
data you're demoing against.** `bin/test` handles this, but the robust fix is a
**test-runner preload** so that even a bare `bun test` (someone forgetting `bin/`,
or an IDE test button) is safe too.

This reference has two halves: the **plumbing** — a dedicated, auto-migrated test DB
(immediately below) — and, once that's in place, **how to author suites against it**
("Authoring tests against the isolated DB", further down).

## The preload (bun example)

`bunfig.toml`:

```toml
[test]
preload = ["./test/setup.ts"]
```

Mind existing `[test]` config: `bun test` globs **across nested packages**, so a
monorepo's root `bunfig.toml` may already carry `[test] pathIgnorePatterns` to
keep sub-package suites out of the root run. **Extend that existing `[test]`
block** with the `preload` key — pasting the snippet as a second `[test]` block
(or overwriting the file) clobbers the ignore patterns and suddenly pulls every
nested package's tests into the run.

`test/setup.ts` runs once before any test file. It must:

1. Default `DATABASE_URL` to the test DB **with `??=`** — so an explicit env
   (CI, or `bin/test` which `export`s it) always wins.
2. Create the test DB if missing (connect to the maintenance `postgres` DB first).
3. Migrate it to the current schema.

```ts
import postgres from 'postgres'
import { drizzle } from 'drizzle-orm/postgres-js'
import { migrate } from 'drizzle-orm/postgres-js/migrator'

const DEFAULT_TEST_URL = 'postgres://app:app@localhost:5432/app_test'
const usingDefault = process.env.DATABASE_URL === undefined

process.env.DATABASE_URL ??= DEFAULT_TEST_URL
process.env.JWT_SECRET ??= 'test-secret-min-32-chars-xxxxxxxxxxxxx'
// ...other required env with ??=

const url = process.env.DATABASE_URL

// Create the DB only when we own the default (CI provides its own, already created).
if (usingDefault) {
  const dbName = new URL(url).pathname.slice(1)
  const adminUrl = new URL(url); adminUrl.pathname = '/postgres'
  const admin = postgres(adminUrl.toString(), { max: 1 })
  try {
    const rows = await admin`SELECT 1 FROM pg_database WHERE datname = ${dbName}`
    if (rows.length === 0) await admin.unsafe(`CREATE DATABASE ${dbName}`)
  } finally { await admin.end({ timeout: 5 }) }
}

const sql = postgres(url, { max: 1 })
try { await migrate(drizzle(sql), { migrationsFolder: './migrations' }) }
finally { await sql.end({ timeout: 5 }) }
```

Then delete the per-file `process.env.DATABASE_URL = …` lines from each test —
the preload centralizes them. Keep any per-suite *override* (e.g. a suite that
sets `MIN_SUPPORTED_BUILD=500` to exercise a code path) — just drop the shared DB/secret defaults.

Apps that read discrete `DB_HOST`/`DB_PORT`/`DB_NAME`/`DB_USER`/`DB_PASSWORD`
vars instead of a URL: `??=` each discrete var the same way — or better, teach
the app to accept `DATABASE_URL` with a discrete-var fallback, so the preload,
`bin/`, and CI all speak one URL.

## Why `??=` and not `=`

`??=` only fills in a default when nothing was provided. CI sets `DATABASE_URL`
explicitly to its ephemeral service-container DB and migrates that itself, so the
preload must defer to it. Using `=` would override CI and break it.

## CI stays untouched

CI already points at a throwaway service-container DB via an explicit
`DATABASE_URL` and runs its own migrate step. This whole pattern is a **local-dev**
change — verify CI is green after adding the preload, but you should not need to
edit the CI workflow.

**Unless CI deliberately has no database.** Some repos run CI DB-less: live-DB
suites self-skip (`describe.skipIf(...)`) and only pure suites gate merges. The
preload as written breaks that CI — it unconditionally connects and migrates,
and there's nothing to connect to. Two legitimate postures; pick one on purpose:

- **Add a service container** (the `ci-quality-gates` default) — DB coverage on
  every PR; the preload works unchanged.
- **Skip when unreachable** — the preload probes Postgres with a
  short-timeout connect; on failure it sets a flag the live-DB suites check
  (feeding their `skipIf`) and returns instead of throwing. Keeps fork PRs and
  minimal runners green at the cost of DB coverage in that lane.

Don't leave it implicit — a preload that hard-fails in a deliberately DB-less CI
looks like a flaky suite, not a design choice.

## Residual footgun to document, not over-engineer

If a dev copies `.env.example` → `.env` with `DATABASE_URL=…/app` (the dev DB),
the test runner auto-loads `.env` and a *bare* `bun test` would defer to it
(the preload uses `??=`). `bin/test` is immune (it `export`s the test URL, which
beats `.env`). Don't try to guard by DB *name* — CI's throwaway DB may legitimately
share the dev name. Just tell people: prefer `bin/test`.

## Verifying it actually works (do this once)

Seed a sentinel row into the dev DB, run the suite both ways, confirm it survived:

```bash
bin/db "INSERT INTO <some_table> (...) VALUES ('SENTINEL — do not delete', ...)"
bin/test                                   # and: (cd <server> && bun test)
bin/db "SELECT count(*) FROM <some_table> WHERE ... LIKE 'SENTINEL%'"  # → still 1
```

Other runners: pytest → a `conftest.py` fixture; vitest → `globalSetup`. Same
three responsibilities (default env, ensure DB, migrate).

# Authoring tests against the isolated DB

The preload gives every run a clean, migrated `app_test`. This is the pattern for
writing suites against it.

> **This half is a single-project pattern** — generalized from the one adopter with
> a real suite so far, so it's n=1. The plumbing above is solid; the conventions
> below are a starting point to **refine after the next project applies them** (see
> the closing note).

## The canonical suite shape

Import the **real app** and drive it **in-process** — no network listener:

```ts
import { afterAll, beforeAll, beforeEach, expect, test } from 'bun:test'
import Fastify, { type FastifyInstance } from 'fastify'

// DATABASE_URL / JWT_SECRET / … come from the preload (bunfig.toml).
const { app } = await import('../src/app.ts')

let server: FastifyInstance

beforeAll(async () => {
  server = Fastify({ logger: false })
  await server.register(app)
  await server.ready()
})
afterAll(async () => {
  await server.close()
})
beforeEach(async () => {
  // wipe only the tables THIS suite touches
  await server.sql`truncate profile, friendship cascade`
})

test('accepting a request connects both ways', async () => {
  const res = await server.inject({ method: 'GET', url: '/v1/friends', headers: alice.auth })
  expect(res.statusCode).toBe(200)
})
```

Four decisions in there are what make isolation actually hold:

### 1. In-process via `inject` — never bind a port

`server.inject(...)` runs the request through the app in memory; the suite never
calls `listen()`. This is the quiet linchpin: a whole directory of suites can run
without fighting over a port — the runner only has to serialize the *database*, not
a socket. It also removes teardown races on a port.

### 2. Reset with a scoped `truncate`, not a global wipe

Each suite truncates **only the tables it touches**, in `beforeEach`, through the
app's own DB handle (`server.sql`, decorated by the app). `… cascade` handles FK
order. Truncate-between-tests is the simplest hermetic reset; a
transaction-per-test rollback is the main alternative (faster, but fights code that
opens its own transactions — start with truncate).

### 3. Fixtures: insert + mint a token, return a handle

Build state through the app's own primitives rather than over HTTP where you can —
insert the row with `server.sql`, mint auth with the app's token signer, hand back a
reusable handle:

```ts
async function makeUser(phone: string) {
  const [row] = await server.sql<{ id: string }[]>`
    insert into profile (phone, claimed_at) values (${phone}, now()) returning id`
  const token = server.signAccessToken(row.id)   // app-decorated signer
  return { id: row.id, auth: { authorization: `Bearer ${token}` } }
}
```

Then drive behaviour over `inject` with `headers: user.auth`. Prefer minting tokens
to replaying the full login flow — exercise the real auth path in the *auth* suite,
and shortcut it everywhere else.

### 4. One process, one DB — so guard shared state

The runner executes every test file in **one process against the one shared
`app_test`**. That's what makes scoped truncates safe — but it means **mutable
process state leaks across suites**:

- **`process.env` bleeds.** A suite that bumps an env knob (e.g. raising a
  minimum-supported-build floor to exercise a 4xx path) must capture the prior value
  in `beforeAll` and **restore it in `afterAll`** — otherwise the override silently
  changes every later suite. Frameworks that read env *at registration time* (e.g.
  `@fastify/env`) sharpen this: set the override *before* `register`, restore after
  `close`.
- **Don't parallelize files against the shared DB.** Scoped truncates assume serial
  execution; running suites concurrently against one DB lets one suite's `truncate`
  yank another's rows mid-test. If you ever need parallelism, give each worker its
  own DB (a per-worker suffix on `app_test`) — don't loosen the reset.

## Stay hermetic (the `ci-quality-gates` line)

Everything above needs only Postgres — no secrets, no outbound calls — so these
suites run in the pre-merge gate (**`ci-quality-gates`**) and on fork PRs. The moment
a test needs real credentials or a third-party endpoint it's a different, later gate;
don't drag secrets into this set. Stub external providers at the app boundary.

## Refine after the next adopter

This authoring playbook is n=1. When the next project picks it up, come back and:
promote what generalized, flag what was project-specific (the framework's
`inject`/decorator details, the truncate-vs-rollback call, the token-minting helper
shape), and add whatever that project hit that this one didn't. Until then, treat the
conventions as defaults to question, not rules.
