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

## Coding style

- Do not use the deprecated `withOpacity` function, use `withAlpha` instead

## Debugging and testing

- When debugging the app with the macos platform, you can take screenshots to see what the screen looks like with this command: `uvx screenshot squadquest --filename .scratch/macos-screenshot.png`
