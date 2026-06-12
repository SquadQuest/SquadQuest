# Screen: Profile

The signed-in user's own profile — view and edit name + photo, and sign out. The post-onboarding
home for the identity that the welcome step first sets. Authenticated; only ever shows the
caller's own profile (there is no other-user profile screen at this stage).

## Route

`/profile`. Reached from the **My Friends timeline** app bar (tapping the user's avatar). Back
returns to wherever the user came from (normally the timeline).

## Data Requirements

- The signed-in profile, already held in the auth controller (`first_name`, `last_name`,
  `photo`, `phone`) — see [`api/profile.md`](../api/profile.md) `GET /v1/me`. No separate fetch
  is required; the screen reads current auth state.

## Display Rules

- **Avatar** — the current `photo` if set, else a person-glyph fallback. Tappable to change
  (the shared photo picker; see [`api/uploads.md`](uploads.md), kind `profile`).
- **Name** — `first_name` (required) and `last_name` (optional), each editable.
- **Phone** — shown read-only (the identity key; not editable here). Display the value as stored.
- A **Save** affordance is enabled only when something changed and a non-empty first name is
  present; disabled/again-idle otherwise. While saving, show a busy indicator and block
  re-submit.
- A **Sign out** action lives on this screen (relocated from the timeline app bar — this is its
  natural home).

## Actions

- **Change photo** — pick + upload via the photo picker; on success the new public URL is held
  pending Save (consistent with the welcome step). Picking a photo does not by itself persist.
- **Edit name** — change first/last name fields.
- **Save** — `PATCH /v1/me` with only the changed fields (`first_name`, `last_name`, `photo`).
  A photo-only change (name untouched) is valid. On success the updated profile replaces auth
  state; surfaces showing the avatar/name reflect it. On failure, show a retryable error and
  keep edits.
- **Want to do** — a link into the user's personal wants backlog
  ([`screens/wants.md`](wants.md)).
- **Ignored** — a low-prominence link into the recovery surface for ignored incoming items
  ([`screens/ignored.md`](ignored.md)).
- **Sign out** — clears the session and returns to the login screen.

## Navigation

- **In:** My Friends timeline app bar → tap avatar.
- **Out:** back → timeline; **Want to do** → `/wants`; **Ignored** → `/ignored`; **Sign out** →
  login.

## Principles

**Inherited:**

- [Audience clarity at the moment of action](../principles.md#audience-clarity-at-the-moment-of-action)
  — a real name + photo is what makes a face-pile / captain line legible; this screen is how a
  user keeps that identity current after onboarding, not only at first launch.

## Notes

- The onboarding gate keys on a null/empty `first_name`; this screen is only reachable once past
  that gate, so a photo-only or last-name edit can never strand the user back in onboarding (first
  name is always already set, and the Save guard keeps it non-empty).
- Photo upload mechanics (signed PUT, kinds, content-types) are owned by
  [`api/uploads.md`](uploads.md); this screen just reuses the picker. Removing/clearing a photo
  (empty-string `photo`) is supported by the API but is a later affordance — not required here.
