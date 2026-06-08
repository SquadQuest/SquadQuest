# API: Messages (squad posts + threads)

Free-text + photo posts. Covers **squad top-level messages** and **thread replies** (the
same primitive — see [`data-model.md`](../data-model.md) `message`). Thread rules in
[`behaviors/thread-drawer.md`](../behaviors/thread-drawer.md). Authenticated.

> The **My Friends** timeline never carries free-text messages — only ideas/activities.
> Free text lives in squads and threads. See
> [private-first](../principles.md#private-first-public-never-touches-the-friends-surface).

## Serialized message

```jsonc
{ "id": "uuid",
  "sender": { "id", "first_name", "photo" },
  "body": "string|null",                 // null ⇒ photo-only
  "attachments": [ { "key", "url" } ],   // photos, rendered as one unit with body
  "thread_count": 3,                      // replies, when this is a thread root
  "created_at": "iso8601" }
```

## POST /v1/squads/:squadId/messages

Post a top-level message to a squad timeline. Requires membership.

- **Request:** `{ "body": "string?", "attachment_keys": ["…"]? }` (at least one of body or
  attachments). → `201 <message>`.

## GET /v1/threads/:targetType/:targetId/messages

Read a thread. `targetType ∈ { activity, community_event, message }`, cursor-paginated.

- **Response:** `{ "items": [<message>…], "next_cursor": … }`.
- Visibility follows the target: an activity thread is visible to that activity's audience;
  a community-event thread to anyone who can see the event; a squad-message thread to squad
  members.

## POST /v1/threads/:targetType/:targetId/messages

Reply in a thread.

- **Request:** `{ "body": "string?", "attachment_keys": ["…"]? }` → `201 <message>`.

## POST /v1/uploads

Get a signed URL to upload a photo (then reference the returned `key` in
`attachment_keys`). See [conventions: Storage](conventions.md#storage-photos).

- **Request:** `{ "content_type": "image/jpeg", "byte_size": 123456 }`
- **Response:** `200 { "key": "…", "upload_url": "https://…", "headers": { … } }`.

## Notes

- New message/thread events fan out over `GET /v1/stream` (`message.created`).
- Photo-only and text+photos render identically as one unit (client concern; the contract
  just carries both fields).

## Principles

**Inherited:**

- [Private-first](../principles.md#private-first-public-never-touches-the-friends-surface) —
  no message endpoint targets the friends timeline; free text is squad/thread only.
