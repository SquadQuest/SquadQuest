---
status: done
depends: [v2-backend-infra, v2-storage-media, v2-app-android-dev-flavor]
specs:
  - specs/behaviors/ci-cd.md
  - specs/api/conventions.md
issues: []
pr: 448
---

# Plan: v2 CI/CD pipelines (CORS + dev APK on develop + branch web previews)

> Extends the existing `develop` publish (prod web + backend) with: a live CORS fix so the web
> app can actually call the API, an automated dev-APK build per develop push, and per-branch web
> previews under `v2.squadquest.app/<branch>/`. See [`specs/behaviors/ci-cd.md`](../specs/behaviors/ci-cd.md).

## Scope

Implement the three publish surfaces and the CORS allow-list the spec describes. One plan, three
coherent parts; the CORS part is the most urgent (web login is broken in prod today).

**In:**

1. **CORS allow-list (live bug fix).**
   - `server/src/plugins/env.ts`: add `ALLOWED_ORIGINS` (string, default `''`).
   - `server/src/app.ts`: replace `origin: NODE_ENV==='production' ? false : true` with an
     allow-list resolver — parse `ALLOWED_ORIGINS` (comma-sep); in non-production also allow
     `localhost`/dev as today. Echo matched origin, `credentials: true`.
   - `tf/cloudrun.tf`: set `ALLOWED_ORIGINS=https://v2.squadquest.app` on the service.
   - Tests: allowed origin echoed; off-list origin blocked; no-Origin (native) unaffected.

2. **Dev APK on develop.** Add a job to `v2-publish.yml`:
   - Set up Flutter + Java/Android SDK; build `./gradlew :app:assembleDevRelease --no-daemon
     --console=plain` with base64 `-Pdart-defines` (API_BASE_URL=prod, CLIENT_HEADER=
     `android/<version>+<run_number>`). (Use gradle directly — `flutter build apk` hangs headless.)
   - Upload to `gs://squadquest-v2-media/apk/squadquest-dev-b<run_number>.apk` (+ optional
     `squadquest-dev-latest.apk`) via the existing WIF auth + `upload-cloud-storage`.

3. **Branch web previews.** New workflow (e.g. `v2-preview.yml`), `on: push` with
   `branches-ignore: [v1]`:
   - Sanitize branch → segment (`feat/x`→`feat-x`); `flutter build web --pwa-strategy=none
     --base-href=/<segment>/`.
   - Upload `app/build/web` to `gs://v2.squadquest.app/<segment>/`; `no-cache` on objects.
   - Backend/Cloud Run + root web deploy stay develop-only (don't run here).

4. **WIF relaxation (`tf/frontend.tf`).** Change the `v2` provider `attribute_condition` from
   `ref=='refs/heads/develop'` to `repository=='SquadQuest/SquadQuest' && ref != 'refs/heads/v1'`.
   (Storybook provider left as-is unless we want previews there too — out of scope.)

**Out:** dedicated preview subdomain/origin (path-based chosen — no new DNS/SSL/LB); auto-pruning
stale previews on branch delete (documented follow-up); iOS build publishing; release-keystore
signing (dev builds stay debug-signed); storybook preview branches.

## Implements

`specs/behaviors/ci-cd.md` (new) and the CORS section added to `specs/api/conventions.md`.
Touches `.github/workflows/` (publish + new preview workflow), `server/src/{app,plugins/env}.ts`,
`tf/cloudrun.tf` (ALLOWED_ORIGINS), `tf/frontend.tf` (WIF condition).

## Approach (refine at pickup)

- Land **CORS first** as its own commit/PR slice — it's the live fix and is independently
  verifiable (curl with an `Origin` header against prod after deploy). The APK + preview jobs can
  follow in the same plan but later commits.
- WIF condition change is `tofu apply` (security-sensitive — call it out in the PR). Verify a
  non-develop branch push can mint a token *after* apply, not before.
- Reuse the exact dev-APK recipe proven this session; parameterize build number from
  `${{ github.run_number }}`.
- Keep the preview workflow's permissions minimal (`id-token: write`, `contents: read`) and its
  steps to build-web + auth + upload only.

## Validation

- [x] CORS: server resolver covered by `cors.test.ts` (allow-list, no-Origin, localhost gating,
      empty-default). `ALLOWED_ORIGINS` applied to Cloud Run via tofu. **Post-merge:** preflight
      from `https://v2.squadquest.app` echoes `Access-Control-Allow-Origin`; off-list blocked.
- [x] **(verified prod)** `main.dart.js` at `https://v2.squadquest.app` contains only
      `https://api.squadquest.app` (zero localhost) — the deployed web build points at prod (fixed
      in #449; see Follow-ups). CORS preflight returns `204` echoing the origin.
- [x] **(verified prod)** develop publish produced `squadquest-dev-b55.apk` + `squadquest-dev-latest.apk`
      (`HTTP/2 200`, ~53.7 MB) in the media bucket (after the IAM grant in #449).
- [x] **(verified prod)** feature-branch push published `v2.squadquest.app/feat-ci-cd-cors/` —
      `200`, correct `<base href="/feat-ci-cd-cors/">` (assets resolve, no white screen).
- [x] **(guarded)** `v1` excluded at all three points: WIF `ref != refs/heads/v1`, publish runs
      only `on develop`, preview `branches-ignore: [develop, v1]`.
- [x] `tofu plan` clean (CORS env: 1 change; WIF condition: 1 change — both reviewed full/untargeted);
      `bun test` 56 pass; `type-check` clean; both workflow YAMLs valid.

## Risks / unknowns

- **WIF relaxation is the sharp edge.** Widening allowed refs must keep `v1` excluded at both the
  WIF condition and the workflow filter (defense in depth). Double-check the CEL expression syntax
  for `!=` on `assertion.ref`.
- Android build time on CI: first run pulls the Gradle distro + deps (slow); rely on
  `subosito/flutter-action` cache + gradle caching to keep develop pushes reasonable.
- base-href correctness: a wrong `--base-href` yields a white screen (assets 404 under the
  subpath). Verify with a real branch push, not just locally.
- Preview bucket growth: no auto-prune at launch — documented, not solved.

## Notes

Built on branch `feat/ci-cd-cors` → PR #448, in two commits:

- **CORS** (`bc72791`): `ALLOWED_ORIGINS` env + pure `isOriginAllowed`/`parseAllowedOrigins`
  resolver (unit-tested without booting the app / mutating `NODE_ENV` — sidesteps the known
  process-wide env-leak footgun). tf env **already applied** to Cloud Run (old image ignores it
  harmlessly; the merge deploys the code that reads it).
- **APK + previews + WIF** (`8347aaa`): `v2-apk` job (idiomatic `flutter build apk --flavor dev`
  — the gradlew workaround was only the local no-TTY harness, not CI); `v2-preview.yml`
  (branches-ignore develop/v1, sanitized segment + base-href); WIF v2 provider relaxed to
  `ref != refs/heads/v1`.

WIF tofu change applied during closeout (reviewed full untargeted plan first). The first develop
publish after #448 then surfaced **two bugs the dry design had hidden** — both fixed in **PR #449**:

1. **Web baked `localhost:4000`.** The `Build web` step never passed `--dart-define=API_BASE_URL`,
   so the deployed site used the client's compile-time default. This — not CORS — was the actual
   login break the user observed; CORS was a real but secondary latent bug. Fixed by adding the
   define to both web builds; the spec now mandates it (with the footgun called out).
2. **APK upload `GcsApiError`.** `v2-github-action` had no write on `squadquest-v2-media` (only the
   frontend buckets). My earlier *manual* `gcloud cp` worked only because it ran as owner —
   masking the gap; CI-as-the-real-SA exposed it. Fixed with an `objectAdmin` grant in `tf/storage.tf`.

Both lessons: a dry-run/manual verification done as a privileged identity can hide IAM gaps and
build-config omissions that only the real CI identity + real build path reveal. The spec
(`behaviors/ci-cd.md`) now encodes both so they can't silently regress.

PRs: #448 (CORS + APK job + previews + WIF), #449 (web-prod-URL + media-bucket IAM fixes).

## Follow-ups

- **Deferred (documented in `behaviors/ci-cd.md`):** stale branch previews are not auto-pruned on
  branch delete — bucket grows unbounded with merged/abandoned branches. A cleanup-on-delete
  workflow is the eventual fix; not blocking.
- **Tracked elsewhere — `v2-test-env-isolation` (not yet stubbed):** the `MIN_SUPPORTED_BUILD`
  process-wide env leak in the bun test suite still stands; the CORS resolver sidesteps it by being
  a pure function, but the underlying footgun remains. (Flagged repeatedly; still wants a stub.)
- **None** for iOS preview/APK publishing — out of scope (Android-only flavors this stage).
