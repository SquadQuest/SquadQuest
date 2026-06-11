# API: Auth

Phone-OTP authentication. We own the auth surface; the backend issues its own JWTs (no
third-party identity in the contract). First verify also **claims** the user's pre-migrated
v1 shell (see [`behaviors/v1-migration.md`](../behaviors/v1-migration.md)).

All routes under `/v1/auth`. See [conventions](conventions.md) for envelope/versioning.

## POST /v1/auth/otp/request

Start phone verification.

- **Request:** `{ "phone": "+15551234567" }` (E.164; server normalizes).
- **Response:** `200 { "expires_in": <seconds> }`. Always 200 for a valid-format number (don't
  reveal whether the number is known). Delivery via a swappable SMS provider — **Twilio Verify**
  in production (Twilio generates, sends, and later checks the code; the server never sees it),
  a dev console provider locally. `expires_in` is advisory (the provider owns the real TTL).
- **Errors:** `phone_invalid`, `rate_limited`.

## POST /v1/auth/otp/verify

Exchange the code for tokens; claim the shell.

- **Request:** `{ "phone": "+15551234567", "code": "123456" }`
- The code is checked by the provider (Twilio Verify in prod; a self-managed `otp_code`
  table for the dev console provider). On success the server proceeds to claim/create.
- **Response:** `200`

  ```jsonc
  {
    "access_token": "…",          // short-lived JWT (Bearer)
    "refresh_token": "…",         // long-lived, rotating
    "profile": { … },             // serialized profile (see below)
    "claimed_v1": true             // whether a v1 shell was claimed on this login
  }
  ```

- **Behavior:** on success, find the `profile` shell by normalized phone; if found and
  unclaimed, bind it to this auth identity and set `claimed_at` (→ `claimed_v1: true`,
  carried friend graph already attached). If no shell, create a fresh profile
  (`claimed_v1: false`). Idempotent: re-verifying an already-claimed profile just logs in.
- **Errors:** `otp_invalid`, `otp_expired`, `rate_limited`.

## POST /v1/auth/refresh

- **Request:** `{ "refresh_token": "…" }`
- **Response:** `200 { "access_token": "…", "refresh_token": "…" }` (refresh rotates).
- **Errors:** `refresh_invalid`, `refresh_revoked` → client must re-OTP.

## POST /v1/auth/logout

- **Request:** `{ "refresh_token": "…" }` → revokes it. `204`.

## Profile shape (serialized)

```jsonc
{ "id": "uuid", "first_name": "…", "last_name": "…", "photo": "https://…signed",
  "phone": "+1…", "claimed_at": "iso8601|null" }
```

## Notes

- The build header (`X-SquadQuest-Client`) is required here too — a below-floor build gets
  `426` before auth proceeds.
- "Not on v2 yet" friends are unclaimed profiles (`claimed_at: null`) reachable through the
  friend graph; see migration spec.

## Principles

**Inherited:**

- [Phone number is the identity bridge](../principles.md#phone-number-is-the-identity-bridge)
  — verify matches the v1 shell by phone.
- [Preserve the social graph; archive the content](../principles.md#preserve-the-social-graph-archive-the-content)
  — claim attaches the carried friend graph; nothing about events is claimed.
