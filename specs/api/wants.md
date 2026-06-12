# API: Wants

A user's personal **backlog of activities they want to do** (the `want` entity — see
[`data-model.md`](../data-model.md)). Each carries a real noun-verb `topic`, so it's "ready to
go": promoting spawns a normal idea via the existing create path. Authenticated.

> **This slice is owner-only.** Every endpoint here reads/writes **only the caller's own** wants.
> Browsing a friend's *shared* wants and overlap alerts are later stages
> (`v2-wants-sharing`, `v2-wants-overlap`); the `visibility` field ships now but grants no
> cross-user access yet.

## Serialized want

```jsonc
{ "id": "uuid",
  "activity_type": { "id", "label" },     // the noun-verb topic (required)
  "title": "string|null",                  // optional free text
  "location": "string|null",               // optional display string
  "notes": "string|null",
  "visibility": "private" | "shared",
  "kind": "one_shot" | "ongoing",
  "archived_at": "iso8601|null",           // set when a one_shot is promoted
  "created_at": "iso8601",
  "updated_at": "iso8601" }
```

## GET /v1/wants

The caller's own wants. Active (non-archived) by default.

- **Query:** `?include_archived=true` to also return archived (promoted one-shots).
- **Response:** `200 { "items": [<want>…] }` — newest first.

## POST /v1/wants

Create a want.

- **Request:** `{ "activity_type_id": "uuid", "title"?, "location"?, "notes"?,
  "visibility"? = "private", "kind"? = "one_shot" }`. `activity_type_id` is **required** and must
  be a real topic (`400 topic_required` / `topic_invalid`).
- **Response:** `201 <want>`.

## PATCH /v1/wants/:id

Edit own want — only provided fields change (`title`, `location`, `notes`, `visibility`, `kind`,
`activity_type_id`). Non-owner (or unknown id) → `404` (not distinguished).

- **Response:** `200 <want>`.

## DELETE /v1/wants/:id

Delete own want. Non-owner/unknown → `404`. → `204`.

## POST /v1/wants/:id/promote

**Promote = spawn.** Create a real idea from this want through any channel the caller can already
publish to, reusing [`POST /v1/ideas`](ideas-activities.md) semantics. The new activity records
`from_want_id`. A `one_shot` want is **archived** (`archived_at` set); an `ongoing` want is left
active and may be promoted again.

- **Request:** the same body `POST /v1/ideas` accepts — `{ "scope"?, "squad_id"?, "audience"?,
  "allow_suggestions"?, "time_options"?, "location_options"?, "community_event_id"? }`. The
  want's `topic` becomes the idea's `activity_type` (the client need not resend it); the want's
  `title`/`location` may seed option hints client-side. The caller must be allowed to post to the
  chosen channel (same checks as `/v1/ideas` — e.g. squad membership).
- **Response:** `201 <activity>` (the serialized idea, as `/v1/ideas` returns), with `from_want`
  set. The want is unchanged except `archived_at` for a `one_shot`.
- Non-owner/unknown want → `404`. Already-archived want → `409 want_archived`.

## Notes

- Promote does **not** introduce a parallel publish path — it delegates to the idea-create logic so
  every channel (My Friends, a squad, the bring-friends bridge) works identically.
- The `visibility` field is stored and editable now, but no endpoint exposes another user's wants
  in this slice — see the deferral note at top.

## Principles

**Inherited:**

- [Private-first](../principles.md#private-first-public-never-touches-the-friends-surface) —
  `shared` ≠ public; even once friend-browsing ships, only **accepted friends** ever see `shared`
  wants, and `private` wants never leave the owner. This slice enforces the strongest form
  (owner-only).
