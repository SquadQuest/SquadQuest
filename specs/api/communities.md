# API: Communities

Open, followable groups whose leaders broadcast born-confirmed recurring events; followers
RSVP with the visibility gradient. Screen rules in
[`screens/communities.md`](../screens/communities.md); attendance rules in
[public attendance is opt-in and tiered](../principles.md#public-attendance-is-opt-in-and-tiered).
Authenticated.

## GET /v1/communities

List/discover communities. `?search=` (case-insensitive name match). Returns all matches as a
flat `{ "items": [...] }` — no cursor yet; real pagination is deferred until community count
warrants it.

- **Item:** `{ "id", "name", "tagline", "icon", "color", "photo", "follower_count", "you_follow": bool, "your_role": "leader" | null }`.
  `icon` is an emoji glyph; `photo` is a public media URL (cover image, nullable) — see
  [`api/uploads.md`](uploads.md).
- `your_role:"leader"` means the caller may post/edit this community's events (drives the
  client's leader controls). It implies `you_follow:true`. A plain follower has `your_role:null`.

## PUT /v1/communities/:id/follow

Toggle following (open/frictionless — no approval).

- **Request:** `{ "follow": true }` → `200 { "you_follow": true, "follower_count": 343 }`.

## GET /v1/communities/:id/events

The community's events.

- **Serialized community_event:**

  ```jsonc
  {
    "id": "uuid",
    "community": { "id", "name", "icon", "color" },
    "title": "Cherry Blossoms Ride",
    "activity_type": { "id", "label" },
    "time": "Wed Apr 1 · 6:30pm",        // next occurrence
    "recurrence": "Every other Wed",
    "location": "Clark Park → Kelly Drive · 10.2mi · Easy",
    "going_count": 64,                   // distinct attendees, anonymous
    "public_going": [ { "id","first_name","photo" } ],  // the opt-in face-pile
    "your_rsvp": { "going": false, "public": false },
    "thread_count": 11
  }
  ```

## PUT /v1/community-events/:id/rsvp

Set the caller's attendance — the **visibility gradient**.

- **Request:** `{ "going": true, "public": false }`.
  - `going:true` → counted in the **anonymous** `going_count`.
  - `public:true` → also added to `public_going` (implies `going:true`).
  - `going:false` clears both.
- **Response:** `200 <community_event>` (updated counts/face-pile).
- A separate explicit act is required to go from counted-anonymous to public — the API
  never sets `public` as a side effect of anything else.

## Leader tooling

Creating/editing communities and posting events. **Creating a community makes you its first
leader**; only a leader may edit the community or author/edit/delete its events. Leadership is
a `community_membership` with `role:"leader"` (it also counts as following).

### POST /v1/communities

Create a community; the caller becomes its `leader` (and a follower).

- **Request:** `{ "name": "…", "tagline"?, "icon"?, "color"?, "photo"? }` — `name` non-empty.
- **Response:** `201 <community item>` with `you_follow:true`, `your_role:"leader"`.

### PATCH /v1/communities/:id

Edit a community. **Leader-only** (non-leader → `403 forbidden`).

- **Request:** `{ "name"?, "tagline"?, "icon"?, "color"?, "photo"? }` — only provided fields change;
  `name` non-empty when present.
- **Response:** `200 <community item>`.

### POST /v1/communities/:id/events

Author a born-confirmed event on the community. **Leader-only** (non-leader → `403`).

- **Request:** `{ "title": "…", "activity_type_id"?, "time"?, "recurrence"?, "location"? }` —
  `title` non-empty; `time`/`recurrence`/`location` are display strings (see data-model).
- **Response:** `201 <community_event>` (zeroed counts, empty face-pile).

### PATCH /v1/community-events/:id

Edit an event. **Leader-only** (of the owning community; otherwise `403`).

- **Request:** `{ "title"?, "activity_type_id"?, "time"?, "recurrence"?, "location"? }` — only
  provided fields change; `title` non-empty when present.
- **Response:** `200 <community_event>`.

### DELETE /v1/community-events/:id

Cancel an event (cascades its RSVPs). **Leader-only** (otherwise `403`).

- **Response:** `204`. Brought-along friends' ideas keep their own life; the `event_ref` they
  embedded simply no longer resolves (tolerant-reader — the idea still shows).

## Notes

- "Bring friends" is **not** here — it posts a friends-scoped idea referencing the event
  (`POST /v1/ideas` with `community_event_id`). The public event stays community-owned; see
  [bring-friends-bridge](../behaviors/bring-friends-bridge.md).
- A brought-along friend who responds "I'm in" is counted in `going_count` (anonymous) but
  never added to `public_going` without their explicit public RSVP.

## Principles

**Inherited:**

- [Public attendance is opt-in and tiered](../principles.md#public-attendance-is-opt-in-and-tiered)
  — the `going` vs `public` split is this principle as a wire contract.
- [Private-first](../principles.md#private-first-public-never-touches-the-friends-surface) —
  community context is the only place public events live; reaching friends requires the
  bridge, not a direct post.
