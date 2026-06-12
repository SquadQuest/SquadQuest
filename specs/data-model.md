# Data Model

The v2 **server-internal** Postgres schema. This is *behind* the versioned API — clients
never see it (see [principles: client binds to the versioned API](principles.md#the-client-binds-to-the-versioned-api-never-the-schema)).
Wire shapes are defined in `api/`. Because nothing outside the API binds to these tables,
the schema is free to evolve via migrations; field names/types here are the intended shape,
not a frozen contract.

Authorization is enforced in the API layer, not via row-level security (RLS is unnecessary
once there is no client-direct access).

This describes entities, key fields, and relationships — not DDL. State machines and
calculations live in the referenced behavior specs.

---

## Carried from v1 (claimed via the migration, keyed by phone)

See [`behaviors/v1-migration.md`](behaviors/v1-migration.md).

### profile

A person. `id` (v2 uuid), `phone` (the identity bridge — unique), `first_name`,
`last_name`, `photo`, notification preferences, `claimed_at` (null = pre-migrated shell not
yet logged in). One per phone.

### friendship

The double-opt-in graph. `requester` → `profile`, `requestee` → `profile`, `status ∈
{requested, accepted}`, plus `ignored_at` (null = visible to the requestee; set = the requestee
ignored it — it stays `requested` but leaves their incoming list for their Ignored list, and the
sender still sees only a pending request). A pair is "friends" when `accepted`. There is **no
`declined`** status — a visible decline would violate
[dismissal is silent and reversible](principles.md#dismissal-is-silent-and-reversible); ignoring is
the silent, recoverable replacement (see [`behaviors/friend-connections.md`](behaviors/friend-connections.md)).
The friends-network (direct friends, and friends-of-friends for discovery) is derived from this.
Unique on (requester, requestee).

### topic + topic_subscription

The interest taxonomy (noun-verb, e.g. "Go Hiking", "Play Basketball") and per-user
subscriptions. `topic`: id, noun, verb, display label. `topic_subscription`: (topic,
profile). Used to surface ideas to friends who share an interest.

---

## New in v2

### activity (the idea ↔ activity record)

The central two-state entity. One row is an **idea** while tentative and a confirmed
**activity** once the captain locks time + place — *two states of one record*, not two
tables. See [`behaviors/ideas-activities-lifecycle.md`](behaviors/ideas-activities-lifecycle.md).

- `id`, `captain` → profile, `activity_type` → topic
- `state ∈ {idea, confirmed}`
- `scope ∈ {friends, squad}`, `squad` → squad (null unless scope=squad)
- `audience` — for friends scope: `{kind: all_friends | people, person_ids?}`
- `allow_suggestions` (bool) — may participants propose extra time/location options
- `confirmed_time_option` / `confirmed_location_option` → option (null until confirmed)
- `community_event` → community_event (null unless this is a **brought-along** plan; see
  [`behaviors/bring-friends-bridge.md`](behaviors/bring-friends-bridge.md))
- `from_want` → want (null unless this activity was **spawned by promoting a want**; back-link
  only — see `want` below)
- `created_at`, `confirmed_at`

### time_option / location_option

Proposed options on an activity. `id`, `activity` → activity, `label`, `created_by` →
profile (the captain, or a participant when `allow_suggestions`). A brought-along plan's
time/place come fixed from its `community_event` rather than from options.

### option_vote

Who voted for which option. (`option`, `profile`). Drives the vote bar and the captain's
confirm decision.

### response

A participant's inline response to an idea/activity. (`activity`, `profile`, `value ∈ {in,
interested, next_time}`). **Absence is the passive dismiss** — there is no "decline" value
(see [response-system](behaviors/response-system.md) and
[lower the stakes](principles.md#lower-the-stakes-of-participation)).

### community

An open, followable group whose leaders broadcast events. `id`, `name`, `tagline`, `icon`
(emoji), `color`, `photo` (public media URL, cover image), `follower_count` (derived).

### community_membership

A follow (and leadership). (`community`, `profile`, `role ∈ {leader, follower}`). Following
is open/frictionless; only `leader` may post events.

### community_event

A leader-broadcast event. Born **confirmed**, **recurring**. `id`, `community` → community,
`title`, `activity_type` → topic, `time` (next occurrence), `recurrence` (e.g. "Every other
Wed"), `location`. Distinct from `activity` — no idea/voting stage. See
[`screens/communities.md`](screens/communities.md).

### community_event_rsvp

The attendance **visibility gradient** (see [public attendance is opt-in and
tiered](principles.md#public-attendance-is-opt-in-and-tiered)). (`community_event`,
`profile`, `going` bool, `public` bool). `going` counts toward the **anonymous headcount**;
`public` additionally puts the person in the **public face-pile**. `public` implies
`going`. Distinct attendees are counted once across direct RSVPs and brought-along
attendance.

### squad + squad_membership

Closed, persistent groups (the evolution of the group text). `squad`: id, name.
`squad_membership`: (`squad`, `profile`, `role ∈ {captain, member}`). Captain controls
membership. Everyone may post (unlike communities).

### message

Text + photo posts. Covers both **squad top-level messages** and **thread replies**.

- `id`, `sender` → profile, `body` (nullable — photo-only allowed), `created_at`
- `attachments` — object-store keys (photo-only or text+photos render as one unit)
- exactly one context:
  - `squad` → squad (a top-level squad timeline message), or
  - `thread_of` — polymorphic thread root: an `activity`, a `community_event`, or a parent
    `message`. Threads are where arbitrary conversation happens; see
    [`behaviors/thread-drawer.md`](behaviors/thread-drawer.md).
- The **My Friends** timeline contains only ideas/activities — never free-text messages
  (those live in squads and threads). See [private-first](principles.md#private-first-public-never-touches-the-friends-surface).

### want

A **loose, shared pre-activity**: an intent to do something + the friends you'd do it with,
captured *before* there's a time or place. The product's founding use case — running into a friend
and saying "I keep my paddleboard in my car, you keep your kayak — let's go to FDR lake soon!" —
is a want: friend each other, create the want, invite them, and when it's mutual, one tap promotes
it to a real dated plan. See [`api/wants.md`](api/wants.md) and [`screens/wants.md`](screens/wants.md).

- `id`, `owner` → profile, `activity_type` → topic (**required** — every want is "ready to go",
  carrying the same noun-verb taxonomy as an activity, so promotion is one tap)
- `title` (optional free text), `location` (optional display string), `notes` (optional)
- `kind ∈ {one_shot, ongoing}` — a `one_shot` is a single thing to do (archives once promoted); an
  `ongoing` is a standing aspiration that **spawns activities repeatedly** and never archives on
  promote.
- `archived_at` (null = active; set when a `one_shot` is promoted)
- `created_at`, `updated_at`

**Privacy is derived, not declared.** There is no `visibility` flag: a want with **no invitees is
private** to the owner; inviting a friend shares it with **exactly** that friend. Impossible to
misconfigure — "keep it private" just means "don't add anyone." See
[private-first](principles.md#private-first-public-never-touches-the-friends-surface).

**Why its own entity, not an `activity` state.** A one-shot want is *nearly* an unpublished
activity — but two things put it one layer above: (1) an **`ongoing`** want never confirms to a
time + place; it **spawns activities again and again**, and an activity can't be a factory of
itself; (2) a want's invitees are *people I'd like to do this with someday*, distinct from an
activity's audience (*who I'm posting this dated plan to now*). **Promote = spawn:** a new
`activity` is created (with `from_want` set; the want's invitees pre-fill the new idea's audience),
reusing the normal idea-create path; the want is never flipped in place.

### want_invite

A friend the owner has tagged onto a want, with that friend's soft response. (`want`, `profile`,
`response ∈ {in, interested, next_time} | null`). Reuses the activity **response vocabulary** (see
[`behaviors/response-system.md`](behaviors/response-system.md)): `null` = invited-not-yet-responded;
there is **no decline** — ignoring is the passive dismiss, never surfaced to the owner as a "no".
The owner sees only positive signal (who's `in` / `interested`). Inviting a friend is what makes a
want shared (and visible) to that friend; an invite never grants the friend edit rights, only the
ability to see it and respond. Unique on (`want`, `profile`).

---

## Archived (NOT in v2)

These v1 tables are **not** carried and have no v2 equivalent at launch. They remain in the
v1 backend, served read-only by the v1 web archive:

- `instances` (events), `instance_members` (RSVPs), `event_messages`
- `location_points` — live location sharing is **deferred** (a possible future v2 feature,
  not in the initial schema)
