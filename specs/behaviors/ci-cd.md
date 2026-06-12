# Behavior: CI/CD — build & publish pipelines

## Rule

Pushes to the v2 trunk and to feature branches produce published artifacts automatically, so
every merge is live and every branch is previewable without manual build steps.

Three publish surfaces, all from GitHub Actions authenticating to GCP via Workload Identity
Federation (no long-lived keys):

| Trigger | Artifact | Destination |
|---|---|---|
| push to `develop` | **prod web** build | `gs://v2.squadquest.app/` (root) → `https://v2.squadquest.app` |
| push to `develop` | **backend image** | Artifact Registry → Cloud Run `squadquest-backend` (migrate-on-startup) |
| push to `develop` | **dev APK** | `gs://squadquest-v2-media/apk/squadquest-dev-b<N>.apk` |
| push to **any branch except `v1`** | **branch web preview** | `gs://v2.squadquest.app/<branch>/` → `https://v2.squadquest.app/<branch>/` |

`develop` is itself "any branch except v1", so a develop push publishes both the root prod web
build *and* (harmlessly) a `/develop/` preview; the root deploy is the canonical one. Treat the
preview of develop as incidental, not a separate product surface.

## Applies To

- `.github/workflows/v2-publish.yml` (develop: web + backend + APK).
- The branch-preview workflow (push to non-`v1` branches: web preview).
- `tf/` Workload Identity Federation providers + the deploy service account's bucket bindings.
- [`api/conventions.md`](../api/conventions.md) CORS allow-list (the web previews + prod web are
  the browser origins the API must allow).

## Details

### Artifact identity & paths

- **APK build number** is the GitHub Actions **run number** (`squadquest-dev-b<run_number>.apk`),
  monotonic and traceable back to a run. The APK is the **`dev` flavor** (`app.squadquest.dev`,
  "SquadQuest Dev") pointed at prod (`--dart-define=API_BASE_URL=https://api.squadquest.app`,
  `CLIENT_HEADER=android/<version>+<run_number>`) so it installs alongside v1 (see
  [`architecture.md`](../architecture.md) build channels). A stable
  `squadquest-dev-latest.apk` copy may also be published for a permanent "newest dev build" link.
- **Branch name → path segment** is sanitized: lowercased, any character outside `[a-z0-9._-]`
  (notably `/` in `feat/x`) replaced with `-`, yielding e.g. `feat/profile-screen` →
  `feat-profile-screen/`. The same sanitized segment is the web `--base-href=/<segment>/` so
  asset URLs resolve under the subpath.
- Web builds use `--pwa-strategy=none` (no service worker — it otherwise serves a stale build
  until a second reload) and are uploaded with `Cache-Control: no-cache` so deploys show up
  immediately (CDN is off; traffic is tiny).
- **Web builds MUST pass `--dart-define=API_BASE_URL=https://api.squadquest.app`** (and a
  `web/<version>+<run_number>` `CLIENT_HEADER`). The client's compile-time default is
  `http://localhost:4000` (see `app/lib/config.dart`), so a web build *without* this define ships
  pointing at localhost and every API call from the deployed site fails — this bit prod once.
  Both the root publish and the branch-preview build carry these defines. (The API origin is the
  same for prod web and every path-based preview, so the CORS allow-list is unaffected.)

### Web preview origin & CORS

A branch preview is served under a **path** of `v2.squadquest.app`, so its browser **origin** is
`https://v2.squadquest.app` — identical to prod web. One CORS allow-list entry therefore covers
prod web and all previews (see [`api/conventions.md`](../api/conventions.md) CORS). No per-branch
DNS, SSL SAN, or LB rule is needed — the existing `v2.squadquest.app` host-rule already routes
every path to the v2 bucket.

> Consequence (acceptable for a dev tool): previews share an origin with prod web, hence share
> browser-local token storage. A preview and prod web can't be signed in as different users in
> the same browser at the same time. If that ever matters, promote previews to a dedicated
> origin (subdomain) — which then needs wildcard CORS + DNS + SSL.

### Trigger gating (Workload Identity Federation)

- The WIF provider attribute condition currently pins to `assertion.ref=='refs/heads/develop'`.
  Branch previews require **relaxing** it to allow any ref in `repository ==
  'SquadQuest/SquadQuest'` **except** `refs/heads/v1` (v1 is the protected production branch and
  must never deploy through the v2 pipeline).
- This is the one security-sensitive change: it widens which refs can mint a deploy token for the
  v2 deploy service account. The SA's permissions are unchanged (write to the v2 + media buckets,
  deploy Cloud Run); only *which branches* can assume it widens. The `v1` exclusion is the guard.
- The branch-preview workflow itself must also exclude `v1` (`branches-ignore: [v1]`) and skip the
  backend/Cloud Run + root web deploy (those stay `develop`-only) — defense in depth alongside the
  WIF condition.

### Idempotency / cleanup

- Re-pushing a branch overwrites its `<branch>/` preview in place (no accumulation per push).
- Stale previews for merged/deleted branches are **not** auto-pruned at launch (a later
  follow-up could add a cleanup on branch-delete). Document the limitation rather than silently
  letting the bucket grow unbounded.

## Principles

**Inherited:**

- [The client binds to the versioned API, never the schema](../principles.md#the-client-binds-to-the-versioned-api-never-the-schema)
  — previews and prod web are just different builds of the same client hitting the same `/v1`
  contract; nothing about a preview changes the API surface.

**Local:**

- **`v1` is sacrosanct in the v2 pipeline.** Every v2 CI trigger explicitly excludes `refs/heads/v1`,
  at both the workflow filter and the WIF condition. v1 ships through its own separate path; a v2
  workflow must never build, deploy, or mint a deploy token for v1. This is why trigger gating is
  "all branches *except* v1" rather than an allow-list — an allow-list would silently fail to
  preview a new branch, but the exclusion makes the one forbidden branch explicit.

## Notes

- Existing state this builds on: `v2-publish.yml` already does prod web + backend on `develop` via
  WIF. APKs already live under `squadquest-v2-media/apk/`.
- **Build command:** on CI, use the idiomatic `flutter build apk --release --flavor dev` with
  `--dart-define`s — it handles flavor + defines cleanly on a hosted runner. (The
  `./gradlew :app:assembleDevRelease` workaround with base64 dart-defines is only needed in the
  local agent harness, where the `flutter build apk` wrapper hangs on a detached/no-TTY process —
  not a CI concern.)
- CORS is currently `origin: false` in production (web is blocked today) — the allow-list change
  is a live bug fix, not just preview enablement.
