---
status: in-progress
depends: [v2-backend-stage2-activities]
specs:
  - specs/api/conventions.md
  - specs/api/auth.md
  - specs/api/timeline.md
  - specs/screens/friends-timeline.md
  - specs/screens/welcome-wizard.md
issues: []
pr:
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

- [ ] `cd app && flutter analyze && flutter test` clean (+ CI `app` job).
- [ ] End-to-end via MCP: server seeded with user+friend+idea; app driven through
      phone→OTP(dev log)→verify → timeline renders the seeded idea (widget_inspector +
      screenshot).
- [ ] signed-out redirect → login; empty-timeline state renders.
- [ ] token persists across relaunch (secure storage); 401 triggers refresh.

## Risks / unknowns

- macOS→localhost ok; document `--dart-define` for other targets (Android emulator 10.0.2.2).
- Single-flight the refresh to avoid storms on parallel 401s.
- Tolerant-reader models so additive backend changes don't break the client.

## Notes

(closeout)

## Follow-ups

(closeout)
