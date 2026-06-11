# Architecture

Foundational tech and topology decisions for SquadQuest v2.

## The Flutter client (`app/`)

The v2 Flutter client lives in **`app/`** — a single app (no separate storybook/v1
entrypoints). Run it from that directory:

```
cd app && flutter run            # default entrypoint app/lib/main.dart
```

Targets **android, ios, macos, web** (windows/linux dropped). Bundle id `app.squadquest`
is preserved from v1 so v2 ships as an app-store update. The v1 app and the original
`lib/v2` mock are archived on the protected `v1` branch; v2 screens are re-ported from there
as they're built against the real backend + specs.

**Build channels (flavors).** The Android build carries a `channel` flavor dimension so a
sideloaded test build is a distinct app from the store build:

- **`prod`** (default) — `applicationId app.squadquest`, label "SquadQuest". The real store
  identity; preserves the v1 bundle id per the update path above.
- **`dev`** — `app.squadquest.dev`, label "SquadQuest Dev". Installs *alongside* v1/prod on the
  same device (a same-id/different-signing-key APK is a hard Android install block, which a
  debug-signed `app.squadquest` build would hit). Used for the milestone APKs published to the
  media bucket for on-device testing.

Both currently sign with the debug key; a release keystore is a later step. Flavors are
**Android-only** for now — iOS schemes/xcconfig flavors are a deferred follow-up, so
`flutter build ipa --flavor …` isn't wired yet. The API base URL and client header are
per-build `--dart-define`s (`API_BASE_URL`, `CLIENT_HEADER`), independent of flavor — a dev
APK points at prod `https://api.squadquest.app` unless told otherwise.

## Backend: custom Fastify/Bun + Postgres (not Supabase)

v2 runs on a **purpose-built backend we own**, not Supabase:

- **API**: Fastify + TypeScript on **Bun**, living in `server/` alongside the Flutter
  client in `app/`.
- **Database**: Postgres (managed host — Neon / Fly Postgres / RDS-class; *swappable*, it's
  just Postgres). Schema evolution is **migration-first** — the schema is free to churn
  because nothing outside the API binds to it.
- **Auth**: phone-OTP → server-issued JWT (access + refresh). OTP delivery via an SMS
  provider (Twilio Verify-class; *swappable*). We own the auth surface.
- **Storage**: object store for photos (R2 / S3 / GCS; *swappable*) with signed URLs.
- **Realtime**: Server-Sent Events for server→client feed/thread updates, plain POSTs for
  writes, fan-out via Postgres `LISTEN/NOTIFY` (Redis pub/sub if/when multi-instance
  fan-out demands it). WebSockets are the upgrade path if bidirectional needs emerge.
  Realtime is an enhancement, never load-bearing (see Principles).

### Why not Supabase

v1's fatal flaw was **clients querying Supabase tables directly** (PostgREST + realtime),
which bound every mobile build to the schema; with unbounded app-update timelines the
schema froze the day it had users. Once the client talks only to a versioned API, the
headline Supabase feature (client-direct CRUD + realtime) is exactly what we're *not*
using — leaving managed Postgres + auth + storage, which we'd rather own in our comfort
stack (Fastify/Bun) than rebuild as Deno Edge Functions. See
[principles: client binds to the versioned API](principles.md#the-client-binds-to-the-versioned-api-never-the-schema).

## The versioned API contract

The client binds to a **versioned API**, never the schema. Summary (full model + the
`/v1/ideas` worked example in [`api/conventions.md`](api/conventions.md)):

- **URL major version** `https://api.squadquest.app/v1/…` — the coarse contract boundary,
  bumped only for a wholesale redesign (years apart, if ever).
- **Within `/v1`: additive / tolerant-reader.** Never remove/retype/repurpose a field a
  released client reads. Break by **superseding** (new path/field + deprecate + delete once
  the upgrade floor passes), not in place.
- **Every request carries the client build** (`X-SquadQuest-Client: <platform>/<version>+<build>`)
  for telemetry, optional per-build response shaping, and the upgrade floor.
- **`min_supported_build` → `426 Upgrade Required`** is the humane floor *and* the
  garbage-collector that lets superseded paths actually be deleted.

## Transition from v1

v2 is a **fresh backend** (per the above), launched as an **app-store update** to v1 (same
bundle ID / signing). Because the backend is fresh, accounts are fresh — users re-authenticate
by phone, which doubles as the identity bridge to their v1 data.

- **v1 is archived**: the existing v1 app stays deployed as a **read-only web build**, the
  home for old events. The v1 native app is superseded by the v2 update.
- **Carry into v2**: profiles + the double-opt-in friend graph + topic interests, via a
  one-time **bulk pre-migration** (claimed on first login, keyed by phone). **Archive**:
  events / RSVPs / event-messages.
- Full mechanics in [`behaviors/v1-migration.md`](behaviors/v1-migration.md). Governed by
  [preserve the social graph; archive the content](principles.md#preserve-the-social-graph-archive-the-content)
  and [phone is the identity bridge](principles.md#phone-number-is-the-identity-bridge).

## Repo layout (target)

```
SquadQuest/
├── app/                     # v2 Flutter client (android/ios/macos/web)
│   ├── lib/                 # screens, router, providers, API client
│   └── (android|ios|macos|web)/
├── server/                  # v2 backend (Fastify/Bun + Postgres)
│   ├── src/
│   │   ├── domain/          # one current domain model + business logic
│   │   ├── routes/v1/       # endpoint wiring under the /v1 boundary
│   │   ├── contracts/       # per-build request parsers + response serializers (edge adapters)
│   │   └── realtime/        # SSE + LISTEN/NOTIFY fan-out
│   └── migrations/          # first-class, forward-only schema migrations
├── specs/                   # this directory
├── plans/                   # work DAG
└── tf/                      # frontend hosting infra (OpenTofu)
```

The v1 Supabase backend and the original root Flutter app are **not** in the v2 trunk — they
live on the protected `v1` branch (archive + migration source). See
[`behaviors/v1-migration.md`](behaviors/v1-migration.md).

## Client stack

Flutter + Riverpod (state) + go_router (routing). The data layer is a typed API client
targeting `/v1`; that client is the single place that knows wire shapes, keeping screens
decoupled from the contract.
