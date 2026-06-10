---
status: in-progress
depends: [v2-communities-core]
specs:
  - specs/api/profile.md
  - specs/api/friends.md
  - specs/behaviors/friend-connections.md
  - specs/screens/welcome-wizard.md
issues: []
pr:
---

# Plan: v2 friend connections + onboarding

## Scope

The two remaining "people" gaps so the app is self-serve: **onboarding** (a freshly
claimed/created user sets their name) and **friend connections** (in-app double-opt-in
requests, so the friend graph isn't seed/migration-only). Backend + client; styling deferred.

**In:**

- onboarding: `PATCH /v1/me` (set first/last name); client routes a null-name user to a
  profile-setup step after login.
- friend connections: `POST`/`GET /v1/friends/requests`, `PUT /v1/friends/requests/:id`
  (send-by-phone w/ shell creation + idempotent/auto-accept, list incoming/outgoing, accept/
  decline); client Friends screen (accepted + incoming requests + add-by-phone).

**Out:** the 3-page welcome PageView intro copy (styling); photo upload (storage); QR /
contact-based connection (future channels); blocking.

## Implements

`specs/api/profile.md` (PATCH /v1/me), `specs/api/friends.md` + `specs/behaviors/friend-connections.md`,
and the profile-setup step of `specs/screens/welcome-wizard.md`.

## Approach

- **Backend** (`server/`):
  - `PATCH /v1/me` in `routes/v1/me.ts` (update first/last name; non-empty first_name).
  - `FriendService`: requestByPhone (normalize → resolve/​create shell → dedup / auto-accept /
    create requested), listRequests (incoming/outgoing), respond (requestee-only accept/
    decline). Reuse `normalizePhone`. Friend/request serializers.
  - routes `routes/v1/friends.ts` (extend) + tests.
- **Client** (`app/`):
  - ProfileRepository.updateProfile (PATCH); AuthController exposes the current profile;
    after sign-in, if `first_name == null` → route `/welcome` (name field → PATCH → go home).
  - FriendRepository: requests(), sendRequest(phone), respond(id, accept). providers.
  - Friends screen (`/friends`): accepted list + incoming requests (accept/decline) +
    add-by-phone field. Reached from a People icon on the timeline app bar.

## Validation

- [ ] `bun run type-check` + `bun test` (PATCH sets name; send-by-phone creates shell +
      requested; reciprocal request auto-accepts; accept connects → appears in GET /friends;
      decline leaves no edge; non-requestee 404; self-request 400) green; CI.
- [ ] client `flutter analyze` + widget tests green; CI.
- [ ] (machine free) MCP: new login → profile-setup sets name; send request by phone →
      pending; accept from the other account → both connected, timeline visible.

## Risks / unknowns

- Shell creation + claim-on-login interplay (a pending request must survive until the
  invitee claims) — reuse the existing shell/claim path.
- One-edge-per-pair idempotency + auto-accept on reciprocal request (don't duplicate edges).
- Onboarding gate: route on null first_name without trapping users who skip (allow a name,
  required to proceed this stage).

## Notes

(closeout)

## Follow-ups

(closeout)
