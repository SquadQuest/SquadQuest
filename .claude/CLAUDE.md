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

A ground-up re-envisioning focused on private/friends-only activity coordination. See **`docs/v2-specs/README.md`** for the full spec including goals, design philosophy, UX concepts, and architecture decisions.

- **`lib/v2/`** — v2 app code (entrypoint, router, screens)
- **`lib/v2/screens/`** — screens copied from storybook and iterated freely
- Screens are designed in storybook first, then copied into `lib/v2/screens/` when ready for the app
- Currently uses mock data; real backend integration will come incrementally

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

## Coding style

- Do not use the deprecated `withOpacity` function, use `withAlpha` instead

## Debugging and testing

- When debugging the app with the macos platform, you can take screenshots to see what the screen looks like with this command: `uvx screenshot squadquest --filename .scratch/macos-screenshot.png`
