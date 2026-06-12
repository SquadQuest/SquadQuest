# API: Wants

A **loose, shared pre-activity**: an intent + the friends you'd do it with, captured before there's
a time or place (the `want` + `want_invite` entities — see [`data-model.md`](../data-model.md)).
Each carries a real noun-verb `topic`, so it's "ready to go": promoting spawns a normal idea via the
existing create path. Authenticated.

> **Privacy is derived.** A want with no invitees is private to its owner; inviting a friend shares
> it with exactly that friend. There is no visibility flag. Only the owner and invited friends ever
> see a want.

## Serialized want

```jsonc
{ "id": "uuid",
  "owner": { "id", "first_name", "photo" },
  "activity_type": { "id", "label" },     // the noun-verb topic (required)
  "title": "string|null",
  "location": "string|null",
  "notes": "string|null",
  "kind": "one_shot" | "ongoing",
  "invitees": [                            // friends tagged onto this want
    { "profile": { "id", "first_name", "photo" },
      "response": "in" | "interested" | "next_time" | null } ],
  "your_response": "in" | "interested" | "next_time" | null,  // when you're an invitee, not the owner
  "archived_at": "iso8601|null",
  "created_at": "iso8601",
  "updated_at": "iso8601" }
```

`your_response` is present only when the caller is an **invitee** (not the owner). The owner sees the
full `invitees` list but only positive/neutral responses — never a "declined" (there is none).

## GET /v1/wants

Wants the caller **owns**. Active (non-archived) by default; `?include_archived=true` to include
promoted one-shots.

- **Response:** `200 { "items": [<want>…] }` — newest first.

## GET /v1/wants/invited

Wants the caller has been **invited to** (owned by friends). The caller's own response is in
`your_response`.

- **Response:** `200 { "items": [<want>…] }` — newest first. Excludes any the caller has hidden
  (see DELETE invite below); excludes archived.

## POST /v1/wants

Create a want (optionally inviting friends in the same call).

- **Request:** `{ "activity_type_id": "uuid", "title"?, "notes"?, "location"?,
  "kind"? = "one_shot", "invitee_ids"? : ["uuid"…] }`. `activity_type_id` required + real topic
  (`400 topic_required` / `topic_invalid`). Each `invitee_id` must be an **accepted friend**
  (`400 not_a_friend`) — inviting is the only way a want reaches anyone else.
- **Response:** `201 <want>`.

## PATCH /v1/wants/:id

Edit own want — `title`, `location`, `notes`, `kind`, `activity_type_id`. Owner only; non-owner/
unknown → `404`.

- **Response:** `200 <want>`.

## DELETE /v1/wants/:id

Delete own want (cascades its invites). Owner only; else `404`. → `204`.

## Invites

### POST /v1/wants/:id/invites

Invite accepted friends to own want (idempotent per friend).

- **Request:** `{ "profile_ids": ["uuid"…] }` — each must be an accepted friend (`400 not_a_friend`).
  Owner only (`404` otherwise).
- **Response:** `200 <want>` (with the updated `invitees`).

### DELETE /v1/wants/:id/invites/:profileId

Owner removes an invitee (un-shares for that friend). → `200 <want>`.

### PUT /v1/wants/:id/response

The **invitee** sets their soft response — `{ "value": "in" | "interested" | "next_time" }`. Reuses
the activity response vocabulary; there is no decline (to dismiss, simply don't respond, or hide it
— see below). Caller must be an invitee (`404` otherwise).

- **Response:** `200 <want>` (with `your_response` updated).

### DELETE /v1/wants/:id/response

Clear your response (back to invited-not-responded). → `200 <want>`.

### DELETE /v1/wants/:id/invited (hide from my list)

An invitee **hides** a want from their own `GET /v1/wants/invited` list (inbox hygiene). This is
**not** a decline and is **never** surfaced to the owner — it only affects the caller's view. →
`204`.

## POST /v1/wants/:id/promote

**Promote = spawn.** Create a real idea from this want through any channel the caller can publish to,
reusing [`POST /v1/ideas`](ideas-activities.md) semantics. **Owner only.**

- **Request:** the same body `POST /v1/ideas` accepts (`scope?`, `squad_id?`, `audience?`,
  `allow_suggestions?`, `time_options?`, `location_options?`, `community_event_id?`). The want's
  `topic` becomes the idea's `activity_type`. **If `audience` is omitted, it defaults to `people`
  scoped to the want's invitees** — the people you wanted to do it with become the people you invite
  to the actual plan; the client may pre-fill + edit this.
- **Response:** `201 <activity>` (the serialized idea), with `from_want` set. A `one_shot` want is
  **archived** (`archived_at` set); an `ongoing` want stays active and may be promoted again.
- Non-owner/unknown → `404`. Already-archived → `409 want_archived`.

## Notes

- Promote introduces **no** parallel publish path — it delegates to the idea-create logic, so every
  channel (My Friends, a squad, the bring-friends bridge) works identically.
- Invites are the entire sharing mechanism: there is no "browse a friend's wants" surface — you see
  a friend's want only because they invited you.

## Principles

**Inherited:**

- [Private-first](../principles.md#private-first-public-never-touches-the-friends-surface) —
  a want reaches another person only by an explicit invite to an **accepted friend**; nothing is
  public, and an un-invited want is owner-only.
- [Lower the stakes of participation](../principles.md#lower-the-stakes-of-participation) —
  invite responses are the same three soft values as activities with **no decline**; ignoring is a
  silent dismiss, and the owner is never shown a "no".
