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
- `incoming` **excludes** requests the caller has ignored (they appear in the Ignored surface
  instead — see below). `outgoing` is unaffected by whether the recipient ignored: a sender always
  sees their request as pending (see
  [dismissal is silent and reversible](../principles.md#dismissal-is-silent-and-reversible)).

## POST /v1/friends/requests

Send a connection request by phone.

- **Request:** `{ "phone": "+1…" }`.
- Resolve the phone → profile (create an unclaimed shell if none). Then:
  - already `accepted` → `200 { "status": "accepted" }` (idempotent),
  - they already requested you → auto-accept → `200 { "status": "accepted" }`,
  - otherwise create/keep a `requested` edge → `201 { "status": "requested" }`.
- Cannot request yourself → `400 cannot_self_request`.

## PUT /v1/friends/requests/:id

Accept an **incoming** request (requestee only).

- **Request:** `{ "accept": true }` → `accepted`.
- **Response:** `200 { "status": "accepted" }`. Non-requestee → `404`.
- There is **no decline.** To make a request go away without connecting, the requestee **ignores**
  it (below) — silent and reversible, never a visible "declined".

## POST /v1/friends/requests/:id/ignore

Ignore an incoming request (requestee only). The edge stays `requested` (the sender keeps seeing a
pending request — unchanged), `ignored_at` is set, and the request leaves `GET
/v1/friends/requests` `incoming` for the caller's **Ignored** surface.

- **Response:** `200 { "status": "requested", "ignored": true }`. Non-requestee → `404`.

## GET /v1/ignored

The caller's ignored incoming items, aggregated across types (see
[`screens/ignored.md`](../screens/ignored.md)). For friend requests, returns the ignored incoming
requests as `<request>` objects tagged by type.

- **Response:** `200 { "items": [ { "type": "friend_request", "id", "profile": <friend>,
  "created_at", "ignored_at" }, … ] }` (want invites and future ignorable types join `items`).

## POST /v1/friends/requests/:id/unignore

Un-ignore — clears `ignored_at`; the request returns to `incoming` exactly as before. Requestee
only.

- **Response:** `200 { "status": "requested", "ignored": false }`.

## Notes

- Only `accepted` edges grant timeline/detail visibility (see friend-connections).
- QR / contact-based connection are future channels; phone is the first.
- Ignoring never notifies or changes anything the sender sees; un-ignoring is always available.

## Principles

**Inherited:**

- [Private-first](../principles.md#private-first-public-never-touches-the-friends-surface) —
  a one-sided request grants no access; only acceptance opens the private surface.
- [Dismissal is silent and reversible](../principles.md#dismissal-is-silent-and-reversible) —
  there is no decline; the requestee ignores (silent to the sender, recoverable from Ignored).
