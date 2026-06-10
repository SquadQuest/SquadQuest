# SquadQuest

SquadQuest v2: a Flutter client (`app/`) talking to a custom Fastify/Bun + Postgres backend
(`server/`) over a versioned API. **`specs/` is the source of truth** — see
**`specs/README.md`** (philosophy in `specs/principles.md`, stack + v1→v2 transition in
`specs/architecture.md`).

A ground-up re-envisioning focused on private/friends-only activity coordination, with
public events reintroduced only inside opt-in Communities.

## Layout

| Path | What |
|---|---|
| `app/` | v2 Flutter client (android/ios/macos/web). Run: `cd app && flutter run` |
| `server/` | v2 backend — Fastify + TypeScript on Bun. Run: `bin/dev` (or `cd server && bun run dev`) |
| `bin/` | dev lifecycle scripts — shared Postgres container, per-worktree databases |
| `specs/` | source of truth (principles, architecture, data-model, api/, screens/, behaviors/) |
| `plans/` | work-in-flight DAG |
| `tf/` | frontend hosting infra (OpenTofu) |

## Client (`app/`)

- Flutter + Riverpod + go_router. The data layer is a typed API client targeting `/v1` — the
  single place that knows wire shapes, keeping screens decoupled from the contract.
- Bundle id `app.squadquest` is preserved from v1 so v2 ships as an app-store update.

## Backend (`server/`)

- Fastify + TypeScript on Bun + Postgres (not Supabase). The client binds **only** to the
  versioned `/v1` API, never the schema (see `specs/api/conventions.md`). Realtime is SSE +
  Postgres `LISTEN/NOTIFY`, treated as an enhancement (never load-bearing).
- Auth/storage/realtime are owned in-house; phone-OTP → JWT.

### Local dev (`bin/` scripts)

A single shared Postgres container (`squadquest-v2-postgres`, host port 5532) hosts a
**separate database per context**, so nothing clobbers anything:

- **Main worktree** → `squadquest_v2` (your canonical dev data).
- **Each agent worktree** → `sq_<hash>` (isolated; many worktrees run at once).
- **The test runner** → `squadquest_test` — so `bun test` **never** touches your dev data.

| Script | Does |
|---|---|
| `bin/setup` | ensure container + this context's DB + `bun install` + migrate |
| `bin/dev` | run the backend with an auto-derived `DATABASE_URL` |
| `bin/test` | run the server suite against `squadquest_test` (ensures + migrates first) |
| `bin/reset-db` | drop + recreate + migrate this context's DB |
| `bin/db "SQL"` | run SQL (or open psql) against this context's DB |
| `bin/cleanup` | drop this worktree's DB (refuses `squadquest_v2` without `--force`) |

Tests are safe even without `bin/`: a bun preload (`server/bunfig.toml` → `test/setup.ts`)
defaults `DATABASE_URL` to `squadquest_test` and migrates it. CI sets `DATABASE_URL`
explicitly, so the preload defers to it (the `??=` lets CI win). There is **no
`docker-compose.yml`** — `bin/` replaces it (compose can't do per-worktree DBs/ports).

## v1 → v2

This trunk (`develop`) is the v2 rebuild. The v1 Supabase backend and the original root
Flutter app (incl. the `lib/v2` mock) are **not** here — they live on the protected **`v1`**
branch, which serves two roles:

- **Reference/archive** for porting (the migration reads it; v2 screens get re-ported from it).
- **Where production keeps shipping.** v1 is still the live app (app stores +
  <https://squadquest.app>) until v2 launches.

> [!IMPORTANT]
> Any fix or update needed before v2 is ready ships to the **`v1`** branch, not to
> `develop`. Don't add v1 features to this trunk.

v2 carries profiles + friend graph + topics over via a bulk pre-migration keyed by **phone**;
events are not ported. v2 reuses v1's bundle id (`app.squadquest`) to ship as an update. See
`specs/behaviors/v1-migration.md`.

## Spec-Driven Development (SpecOps)

`specs/` is the **source of truth** for v2: specs declare the desired state, code conforms.

- **Read the relevant spec before implementing** any v2 screen/endpoint/behavior. It says
  *what* must be true, not *how*. If a spec is ambiguous or wrong, fix the spec first.
- Layout: `specs/principles.md` (the decisive philosophy), `architecture.md`,
  `data-model.md`, `api/` (the versioned contract), `screens/`, `behaviors/`. See
  `specs/README.md`.
- Feature specs reference the `principles.md` entries that govern them; honor those
  principles for any decision the enumerated rules don't cover.
- Run **`/audit-spec-drift`** to compare `specs/` against the implementation. Treat
  spec↔code divergence as a bug.

## Plans

Work-in-flight is tracked in `plans/` (motion), distinct from `specs/` (state). A new chunk
of work starts with a plan file; its last commit before merge flips `status` to `done`.

- Statuses: `planned | in-progress | done | blocked | cancelled`.
- The SpecOps CLI queries the plan DAG on demand (don't hand-maintain a status table):
  `scripts/specops` (dashboard), `next`, `dag`. The session hook loads the dashboard at
  startup. Full protocol: SpecOps skill `references/plans-protocol.md`. See `plans/README.md`.

## Working agreements (for all contributors)

These apply to every contributor working in this repo.

### Tool management (`asdf`)

Tool versions are pinned in `.tool-versions`. **Never hand-edit that file** — run
`asdf set <tool> <version>` then `asdf install`. Prefer a floating selector unless there's a
compelling reason to pin an exact version: `asdf set opentofu latest`, or
`asdf set nodejs latest:22` to track the newest within a major. If a tool seems missing even
though it's listed, the fix is `asdf install`, not a manual install.

### Package managers — one per surface

| Surface | Manager | Add dep | Lockfile to commit |
|---|---|---|---|
| `app/` (Flutter client) | `flutter` / `dart pub` | `flutter pub add <pkg>` | `pubspec.lock` |
| `server/` (v2 backend) | `bun` | `bun add <pkg>` | `bun.lock` |

Never hand-edit `pubspec.yaml` / `package.json` — use the manager so compatible versions are
selected, and commit the lockfile alongside the manifest change.

### JSON processing

Use `jq` for every JSON filter/shaping operation. Don't write one-shot node/python/ruby
scripts to manipulate JSON.

### Terraform / infra

`tf/` is **OpenTofu** — use `tofu`, never `terraform`. Always pass `-concise` on `plan` and
`apply`.

### Browser + GitHub tools

- Browser automation: use `chrome-devtools-axi` via Bash — not Playwright/Puppeteer.
- GitHub operations: use `gh-axi` instead of `gh` (token-efficient output + contextual
  suggestions). When adding/modifying `.github/workflows/`, use `gh-axi repo view <owner>/<action>`
  to confirm the latest recommended action version before pinning.

### Source control

Conventional commits with surface-scoped scopes so history reads as a per-surface changelog:

| Scope | Covers |
|---|---|
| `feat(app):` / `fix(app):` / `refactor(app):` | `app/` (Flutter client) |
| `feat(server):` / `fix(server):` | `server/` (v2 backend) |
| `docs(specs):` | `specs/` |
| `docs(plans):` | `plans/` |
| `chore(specops):` | SpecOps tooling (hook, drift auditor, CLI wiring) |
| `chore(tf):` / `feat(tf):` | `tf/` (frontend hosting / infra) |
| `chore(ci):` | `.github/workflows/` |
| `docs(repo):` | root README / CLAUDE.md / cross-cutting repo docs |

- **Commit often, in logical units.** Don't let unrelated work pile up uncommitted — commit
  each logical set of changes as soon as it's coherent. A session touching both `specs/` and
  `app/` is at least two commits.
- Always run `git status` before staging, and **stage explicit paths — never `git add -A`
  or `git add .`**.
- When a command modifies files (`flutter pub add`, `bun install`, `bunx`/codegen), commit
  those generated changes *first* in a commit whose body names the exact command, then make
  hand edits in a separate commit.
- Branch off `develop` for non-trivial work; open PRs into `develop`.

## Coding style

- Do not use the deprecated `withOpacity` function, use `withAlpha` instead

## Debugging and testing

- When debugging the app with the macos platform, you can take screenshots to see what the screen looks like with this command: `uvx screenshot squadquest --filename .scratch/macos-screenshot.png`
