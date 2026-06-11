# API: Profile (me)

The authenticated user's own profile. Authenticated.

## GET /v1/me

The caller's profile.

- **Response:** `200 { "id", "first_name", "last_name", "photo", "phone", "claimed_at" }`.

## PATCH /v1/me

Update the caller's own profile (the onboarding profile-setup + later profile edits).

- **Request:** `{ "first_name"?: "string", "last_name"?: "string", "photo"?: "string" }` — only
  provided fields change. `first_name` must be non-empty when present. `photo` is a public media
  URL from [`api/uploads.md`](uploads.md); an empty string clears it.
- **Response:** `200 <profile>`.
- **`needs_onboarding`:** a freshly-claimed/created profile has `first_name = null`. Clients
  treat a null `first_name` as "needs onboarding" and route to the welcome/profile-setup step.

## Notes

- A fresh phone-OTP user (or a claimed pre-migration shell) starts with no name; PATCH is how
  the welcome wizard sets it. See [`screens/welcome-wizard.md`](../screens/welcome-wizard.md).

## Principles

**Inherited:**

- [Audience clarity at the moment of action](../principles.md#audience-clarity-at-the-moment-of-action)
  — a real name is what makes a public face-pile / captain line meaningful; onboarding sets it
  before those surfaces show "Someone".
