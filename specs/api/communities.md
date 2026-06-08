# API: Communities

Open, followable groups whose leaders broadcast born-confirmed recurring events; followers
RSVP with the visibility gradient. Screen rules in
[`screens/communities.md`](../screens/communities.md); attendance rules in
[public attendance is opt-in and tiered](../principles.md#public-attendance-is-opt-in-and-tiered).
Authenticated.

## GET /v1/communities

List/discover communities. `?search=`, cursor-paginated.

- **Item:** `{ "id", "name", "tagline", "icon", "color", "follower_count", "you_follow": bool }`.

## PUT /v1/communities/:id/follow

Toggle following (open/frictionless — no approval).

- **Request:** `{ "follow": true }` → `200 { "you_follow": true, "follower_count": 343 }`.

## GET /v1/communities/:id/events

The community's events (also surfaced via `GET /v1/communities/:id/timeline`).

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

## Leader-only (deferred to a later plan)

Creating/editing communities and posting/scheduling events is **leader tooling**, not in
the first contract. Noted here so the read/RSVP/follow surface is understood as
follower-facing. Tracked as a follow-up.

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
