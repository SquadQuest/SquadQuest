# SquadQuest

A Flutter app powered by a Supabase backend with three coexisting entrypoints:

## Entrypoints

| Entrypoint | Run command | Purpose |
|---|---|---|
| **v1 app** | `flutter run -t lib/main.dart` | Current production app (`lib/ui/` screens) |
| **Storybook** | `flutter run -t lib/storybook/main.dart` | Design exploration with mock data |
| **v2 app** | `flutter run -t lib/v2/main.dart` | V2 redesign demo/app (see below) |

All three share the same `pubspec.yaml`, `lib/models/`, `lib/controllers/`, `lib/services/`, theme, and native configs (bundle IDs, signing). They differ only in their routing, screens, and provider overrides.

## V2 Redesign

A ground-up re-envisioning focused on private/friends-only activity coordination, with
public events reintroduced only inside opt-in Communities. **`specs/` is the source of
truth** for v2 — see **`specs/README.md`** (philosophy in `specs/principles.md`, stack +
v1→v2 transition in `specs/architecture.md`).

- **`lib/v2/`** — v2 app code (entrypoint, router, screens); currently mock data
- **`lib/v2/screens/`** — screens copied from storybook and iterated freely
- Screens are designed in storybook first, then copied into `lib/v2/screens/`
- **v2 runs on a fresh, custom backend** — Fastify/Bun + Postgres in `server/` (forthcoming),
  **not** Supabase. The client binds only to a versioned API, never the schema. v1's Supabase
  backend is archived read-only; profiles + friend graph + topics migrate over (keyed by
  phone), events do not. See `specs/architecture.md` and `specs/behaviors/v1-migration.md`.

## Storybook

Used to showcase and iterate on new screen designs before implementation:

- `lib/storybook/screens/` — design iteration screens
- `lib/storybook/components/` — shared storybook elements
- `lib/storybook/main.dart` — navigation menu (all screens registered here)

## V1 App

The current production app:

- `lib/ui/` — production screens
- `lib/main.dart` — production entrypoint
- Unless explicitly told to work on storybook or v2, assume tasks are about v1

## Shared Code

- `lib/models/` — data models (frontend)
- `lib/controllers/` — Riverpod state management
- `lib/services/` — core services (supabase, auth, notifications, router)
- `lib/theme.dart` — Material theme definitions
- `lib/app_scaffold.dart` — shared layout scaffold
- `supabase/` — backend (tables, functions, migrations)

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
| Flutter app (`lib/`) | `flutter` / `dart pub` | `flutter pub add <pkg>` | `pubspec.lock` |
| `server/` (forthcoming v2 backend) | `bun` | `bun add <pkg>` | `bun.lock` |

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
| `feat(v2):` / `fix(v2):` / `refactor(v2):` | `lib/v2/` |
| `feat(storybook):` | `lib/storybook/` |
| `feat(server):` / `fix(server):` | `server/` (the v2 backend) |
| `docs(specs):` | `specs/` |
| `docs(plans):` | `plans/` |
| `chore(specops):` | SpecOps tooling (hook, drift auditor, CLI wiring) |
| `chore(tf):` / `feat(tf):` | `tf/` (frontend hosting / infra) |
| `ci(v2):` / `chore(ci):` | `.github/workflows/` |
| `feat:` / `fix:` (unscoped) or `(v1)` | the v1 production app (`lib/ui/`, `lib/main.dart`) |

- **Commit often, in logical units.** Don't let unrelated work pile up uncommitted — commit
  each logical set of changes as soon as it's coherent. A session touching both `specs/` and
  `lib/v2/` is at least two commits.
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
