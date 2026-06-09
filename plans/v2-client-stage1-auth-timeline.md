---
status: done
depends: [v2-backend-stage2-activities]
specs:
  - specs/api/conventions.md
  - specs/api/auth.md
  - specs/api/timeline.md
  - specs/screens/friends-timeline.md
  - specs/screens/welcome-wizard.md
issues: []
pr: 412
---

# Plan: v2 client Stage 1 — auth + friends timeline (wired to /v1)

## Scope

First real vertical slice of the `app/` Flutter client: phone-OTP login → JWT → the live
My Friends timeline from `GET /v1/timeline/friends`. Establishes the client architecture
(typed `/v1` API client on dio, Riverpod, go_router, secure token storage). Minimal-functional
UI — the polished v2 mock re-port is a later stage.

Out: rich mock UI; communities/squads/threads screens; idea composer; thread drawer; SSE
realtime; push; profile editing; friend-connection/QR.

## Implements

Client side of `specs/api/{conventions,auth,timeline}.md` + `specs/screens/friends-timeline.md`
and the login portion of `specs/screens/welcome-wizard.md`.

## Approach

- Deps: dio, flutter_riverpod, go_router, flutter_secure_storage.
- **api/**: dio `ApiClient` — `API_BASE_URL` (`--dart-define`, default <http://localhost:4000>),
  `X-SquadQuest-Client` header, bearer-token injection, single-flight 401→`/v1/auth/refresh`
  →retry, error-envelope→`ApiException(code)`.
- **models/**: tolerant `fromJson` for Profile, Friend, Activity (+ options/counts).
- **data/**: AuthRepository (otp request/verify/refresh/logout + token persistence),
  TimelineRepository (friends), ProfileRepository (me).
- **auth/**: secure token store + `authController` (signedOut|awaitingOtp|signedIn).
- **router.dart**: go_router auth-gated redirect.
- **features/login** + **features/timeline**: the two screens + providers.

## Validation

- [x] `cd app && flutter analyze && flutter test` clean (+ CI `app` + `server` jobs green on #412).
- [x] End-to-end via MCP: server seeded with user+friend+idea; app driven through
      phone→OTP(dev log)→verify → timeline rendered the seeded idea
      ("Katie · Go Paddleboarding · Idea · all friends") via widget_inspector + screenshot.
- [x] signed-out redirect → login (verified on launch); empty-timeline state (widget test).
- [~] token persistence + 401-refresh: single-flight refresh implemented; **not** exercised
      end-to-end. On unsigned macOS the keychain rejects writes so tokens live in-memory only
      (no cross-relaunch persistence) — signed builds persist. See Follow-ups.

## Risks / unknowns

- macOS→localhost ok; document `--dart-define` for other targets (Android emulator 10.0.2.2).
- Single-flight the refresh to avoid storms on parallel 401s.
- Tolerant-reader models so additive backend changes don't break the client.

## Notes

Shipped as PR #412 (4 commits: vendor mobile-flutter skill, deps, client impl, tests+plan);
CI green. Structure follows the **mobile-flutter** skill (loaded mid-stage): top-level
`lib/{api,models,repositories,providers,screens}` + `app.dart`, **abstract repositories with
Api impls + fakes-via-Riverpod-override** (the timeline widget test uses a `FakeTimelineRepository`).
This replaced the initial ad-hoc `lib/src/{data,features}` layout.

Bugs caught during MCP-driven verification: `POST /v1/ideas`-style snake_case→camelCase wasn't
the issue here, but the login `verifyOtp` path surfaced two real macOS issues (below).

macOS findings (deliberate divergences from the skill's gotchas, worth feeding back):

- Added `com.apple.security.network.client` (outbound API) to both entitlement files.
- `flutter_secure_storage` on an **unsigned** dev build fails: `-34018` (data-protection
  keychain needs an application-identifier entitlement = signing) and `-25308` (file-based
  ACL). Mitigations applied: `MacOsOptions(usesDataProtectionKeychain: false)`, drop
  `app-sandbox` in **Debug** only (Release keeps it), and `TokenStore` swallows keychain
  failures → in-memory session so auth never breaks.
- flutter_driver tap timed out on the autofocused field (blinking-cursor keeps frames
  pending) → `set_frame_sync(false)` before driving.

Config uses `--dart-define=API_BASE_URL` (build-time) rather than the skill's `.env` — a
deliberate choice for a non-secret endpoint; flagged for the user.

## Follow-ups

- **Tracked as (skill feedback):** feed the macOS gotchas back into the `mobile-flutter` skill —
  (a) unsigned keychain needs `usesDataProtectionKeychain:false` + Debug sandbox-off OR a
  signing team; (b) `set_frame_sync(false)` before flutter_driver interactions; (c) `.env` vs
  `--dart-define` guidance.
- **Deferred (needs signing):** verify real keychain persistence across relaunch + the
  401→refresh→retry path end-to-end once a macOS development team / app signing is configured.
- **Deferred to plan:** re-port the polished v2 mock UI (cards/thread drawer/composer) from the
  `v1` branch; idea composer + respond/vote/confirm/options from the client; communities/squads/
  threads screens; SSE realtime; push; profile editing; friend-connection/QR.
