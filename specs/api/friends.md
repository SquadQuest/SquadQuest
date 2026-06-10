# API: Friends

The accepted friend graph + connection requests (double opt-in). Authenticated. Connection
model in [`behaviors/friend-connections.md`](../behaviors/friend-connections.md).

## Serialized friend / requester

```jsonc
{ "id", "first_name", "last_name", "photo", "on_v2": bool }
```

`on_v2:false` = a carried/pre-migration friend (or a shell) who hasn't claimed v2 yet.

## GET /v1/friends

The caller's **accepted** friends.

- **Response:** `200 { "items": [<friend>…] }`.

## GET /v1/friends/requests

Pending connection requests involving the caller.

- **Response:** `200 { "incoming": [<request>…], "outgoing": [<request>…] }`
  where a request is `{ "id", "profile": <friend>, "created_at" }` — `profile` is the *other*
  party (the sender for incoming, the target for outgoing).

## POST /v1/friends/requests

Send a connection request by phone.

- **Request:** `{ "phone": "+1…" }`.
- Resolve the phone → profile (create an unclaimed shell if none). Then:
  - already `accepted` → `200 { "status": "accepted" }` (idempotent),
  - they already requested you → auto-accept → `200 { "status": "accepted" }`,
  - otherwise create/keep a `requested` edge → `201 { "status": "requested" }`.
- Cannot request yourself → `400 cannot_self_request`.

## PUT /v1/friends/requests/:id

Respond to an **incoming** request (requestee only).

- **Request:** `{ "accept": true }` → `accepted`; `{ "accept": false }` → `declined`.
- **Response:** `200 { "status": "accepted" | "declined" }`. Non-requestee → `404`.

## Notes

- Only `accepted` edges grant timeline/detail visibility (see friend-connections).
- QR / contact-based connection are future channels; phone is the first.

## Principles

**Inherited:**

- [Private-first](../principles.md#private-first-public-never-touches-the-friends-surface) —
  a one-sided request grants no access; only acceptance opens the private surface.
