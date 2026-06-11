---
status: done
depends: [v2-backend-infra]
specs:
  - specs/api/auth.md
issues: []
pr: 436
---

# Plan: v2 SMS OTP (Twilio Verify)

## Scope

Make real phone login work on the live backend by delivering + checking OTP codes via
**Twilio Verify** (reusing the v1 SquadQuest Verify service), instead of the dev-only
`ConsoleOtpProvider` that logs the code. Backend-only; no client or wire-contract change
(the `/v1/auth/otp/{request,verify}` shapes stay identical).

**In:**

- Broaden the `OtpProvider` abstraction from one-way delivery (`send(phone, code)`) to the
  **start/check** model Twilio Verify uses: `start(phone)` and `check(phone, code) → boolean`.
  Twilio owns code generation + verification; we never see the code.
- `TwilioVerifyOtpProvider` — calls Verify's `/Services/{sid}/Verifications` (start) and
  `/VerificationCheck` (check) via the REST API (no SDK; small fetch wrapper).
- `ConsoleOtpProvider` keeps working for local dev by retaining the self-managed `otp_code`
  table behind the same start/check interface (so AuthService has one code path).
- Provider selection by env: if `TWILIO_*` are present → Twilio; else → Console (dev).
- Wire the 3 secrets into Cloud Run (`tf/cloudrun.tf`): `TWILIO_ACCOUNT_SID`,
  `TWILIO_AUTH_TOKEN`, `TWILIO_VERIFY_SERVICE_SID` from the existing Secret Manager containers.
- Env schema (`plugins/env.ts`) gains the 3 optional Twilio vars.
- Tests: provider selection; Console path still self-manages codes; AuthService verify still
  claims/creates profile correctly with a fake start/check provider.

**Out:** rate-limiting beyond what Verify provides; alternate channels (email/WhatsApp);
changing the JWT/refresh model; client changes (none needed).

## Implements

`specs/api/auth.md` — the OTP request/verify endpoints (delivery becomes real SMS; the spec
already says "Delivery via SMS provider (swappable)"). A spec touch-up notes Verify owns
code gen/check and that `otp_invalid`/`otp_expired`/`rate_limited` now also map from Verify
responses.

## Approach

- **Refactor `OtpProvider`** to `{ start(phone): Promise<void>; check(phone, code): Promise<boolean> }`.
  AuthService.requestOtp → `provider.start(phone)`; AuthService.verifyOtp → `provider.check(...)`,
  and on `true` proceed to the existing claim/create + token issue (unchanged).
- **ConsoleOtpProvider** absorbs the current `otp_code` self-managed logic (generate+hash+store
  on start; compare+attempts+consume on check) so dev keeps working with no DB change. The
  `otp_code` table stays (Console uses it; Twilio ignores it).
- **TwilioVerifyOtpProvider**: REST calls with basic auth (account SID + auth token), service
  SID in the path. `start` POSTs `To=<phone>&Channel=sms`; `check` POSTs `To=<phone>&Code=<code>`
  and returns `status === 'approved'`. Map Twilio errors → our `otp_*` codes.
- **Wiring**: `routes/v1/auth.ts` picks the provider from config; `tf/cloudrun.tf` adds 3
  `env { value_source { secret_key_ref } }` blocks (the containers + accessor already exist).
- Reuse `normalizePhone` for the `To` value (E.164).

## Validation

- [x] `bun test` + type-check: Console start/check self-manages `otp_code` (request→verify,
      wrong code → otp_invalid + attempts, no-request → otp_expired, seeded-code happy path
      claims/creates + issues tokens). 3 new tests; suite 44/44; `tsc --noEmit` clean.
- [x] Twilio env wired into Cloud Run from Secret Manager (`tofu apply`: service updated,
      TWILIO_* present); `tofu plan` clean. Provider auto-selects Twilio when the 3 vars are set.
- [ ] (live, manual) `POST /v1/auth/otp/request` to a real phone delivers an SMS via Verify and
      verify returns tokens — confirm once the CI deploy ships this code to prod.

## Risks / unknowns

- **Verify semantics differ from self-managed**: no `expires_in` we control (Verify's default
  ~10 min). Keep returning a sensible `expires_in` for the contract; document it's advisory.
- **Re-request / rate limits**: Verify rate-limits starts per number; surface as `rate_limited`.
- **`otp_code` table now dual-purpose** (Console only). Don't drop it; note it's dev-path.
- **Secret names**: env var names (`TWILIO_*`) vs secret IDs (`twilio-*`) — map explicitly in tf.
- Test isolation: don't hit Twilio in tests — select the fake/Console provider by env.

## Notes

PR #436. `OtpProvider` broadened from `send(phone,code)` to `start(phone)` + `check(phone,code)`
- `ttlSeconds` — the start/check model Twilio Verify requires (Twilio owns code gen + delivery
- verification; the server never sees the code). `ConsoleOtpProvider` absorbed the old
self-managed `otp_code` logic so dev/tests keep working with no DB change and no external dep;
`AuthService` is now provider-agnostic (verify just calls `check()` then claims/creates). Routes
select Twilio when all 3 `TWILIO_*` env are present, else Console (with a warn log). tf wires the
3 secrets into Cloud Run; the env landed on the live service via `tofu apply` (inert until the CI
deploy ships this code, which then activates Twilio in prod).

The `otp_code` table is now **dev-path only** (Console provider) — kept, not dropped.

## Follow-ups

- **Verification owed (manual):** send a real OTP to a real phone in prod once CI deploys this —
  confirm SMS arrives and verify returns tokens. Tracked in Validation.
- **Tracked as:** Verify owns the real code TTL (~10 min); `expires_in` is advisory. If clients
  need an exact countdown, revisit.
- **None** else — auth is functionally complete; CI auto-deploy will roll this to prod on merge.
