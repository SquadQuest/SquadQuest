---
status: done
depends: [v2-communities-core]
specs:
  - specs/api/profile.md
  - specs/api/friends.md
  - specs/behaviors/friend-connections.md
  - specs/screens/welcome-wizard.md
issues: []
pr: 426
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

- [x] `bun run type-check` + `bun test` (PATCH sets name + rejects blank; send-by-phone creates
      shell + requested; reciprocal request auto-accepts as one edge; accept connects → appears
      in GET /friends; decline leaves no edge + re-requestable; non-requestee 404; self-request
      400) green — suite **36/36**; CI green on #425.
- [x] client `flutter analyze` + widget tests green — **16** tests (welcome ×2, friends ×4 +
      updated fakes); CI green on #426.
- [ ] (machine free) MCP: new login → profile-setup sets name; send request by phone →
      pending; accept from the other account → both connected, timeline visible.

## Risks / unknowns

- Shell creation + claim-on-login interplay (a pending request must survive until the
  invitee claims) — reuse the existing shell/claim path.
- One-edge-per-pair idempotency + auto-accept on reciprocal request (don't duplicate edges).
- Onboarding gate: route on null first_name without trapping users who skip (allow a name,
  required to proceed this stage).

## Notes

Two PRs: **#425** (backend — `PATCH /v1/me`; `FriendService` with requestByPhone shell-creation
- one-edge-per-pair idempotent/auto-accept, listRequests, requestee-only respond; request
serializer; no migration) and **#426** (client — `/welcome` onboarding gate off the signed-in
profile, `/friends` People screen with accepted graph + incoming accept/decline + outgoing
pending + add-by-phone, `patch()` verb, FriendRepository/ProfileRepository extensions). Both
CI-green and merged. The friend graph is now self-serve (was seed/migration-only) and new users
set a name before any surface shows "Someone".

Decisions worth noting: a **declined** edge is re-opened (not blocked) when either party
re-sends — `requestByPhone` flips it back to `requested` with the sender as requester, keeping
one edge per pair. The onboarding gate keys purely on null/empty `first_name`; there's no skip
(a name is required to proceed this stage).

The third validation item (live MCP walkthrough + screenshots) is pending a free machine —
tracked below, not blocking the merge since both automated gates are green.

## Follow-ups

- **Deferred (UX/styling):** the 3-page welcome PageView intro copy; profile **photo** upload
  (needs storage); editing your name later from a settings/profile screen (PATCH already
  supports it — just no client entry point yet).
- **Deferred to plan / future channels:** **QR / contact-based** friend connection (phone is the
  only channel now); **blocking** (decline ≠ block today — promote `friend-connections.md`'s
  Local principle if blocking arrives).
- **Verification owed:** live MCP walkthrough (new login → profile-setup → request-by-phone →
  accept from the other account → both connected) + screenshots, when the machine is free.
