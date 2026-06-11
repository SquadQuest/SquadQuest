# Screen: Community Timeline

A community context — an open, followable group whose **leaders broadcast** events. The
controlled home for public events in v2.

## Route

Selected from the [context selector](../behaviors/context-selector.md) (a Community entry).
Title bar shows the community icon + name, tappable to switch context.

## Data Requirements

- `GET /v1/communities/:id/events` — serialized `community_event` objects
  (see [`api/communities.md`](../api/communities.md)), each with `going_count`,
  `public_going` (face-pile), `your_rsvp`, `recurrence`, `thread_count`.

## Display Rules

- A feed of **born-confirmed, recurring event cards** (solid/confirmed styling), authored by
  the community (icon + name + recurrence on the author line), not by a friend captain.
- **Dual attendance** on each card:
  - an **anonymous headcount** ("64 going"), and
  - an opt-in **public face-pile** ("Maya, Jordan +6 publicly").
  The gap between them is intentional and reassuring.
- The input area is **replaced by a read-only follower banner** ("Following · only leaders
  post events here") — followers don't post to the community timeline.
- **For a leader** (`your_role:"leader"`), the follower banner is replaced by a **"Post event"**
  affordance, and the title bar exposes an **edit-community** action. Leader-authored event
  cards carry **edit/delete** affordances. A non-leader never sees these.

## Actions

- **RSVP (visibility gradient):** a "Going" toggle (→ anonymous count) and a separate "Show
  name" toggle (→ public face-pile; implies going). `PUT /v1/community-events/:id/rsvp`.
  Going never escalates to public without the explicit second toggle. See
  [public attendance is opt-in and tiered](../principles.md#public-attendance-is-opt-in-and-tiered).
- **Bring friends:** opens the idea composer pre-filled with the event (switches to My
  Friends), posting a friends-scoped idea referencing it. See
  [bring-friends-bridge](../behaviors/bring-friends-bridge.md).
- **Follow / unfollow** the community. (A leader stays a member — unfollow never strips
  leadership.)
- **Open an event** → thread (chat + RSVP in header). [thread-drawer](../behaviors/thread-drawer.md).
- **Leader — create a community:** from Discover, a "New community" entry opens a create form
  (`POST /v1/communities`); on success the new community becomes the active context, with the
  caller as leader. `screens/discover-communities` hosts the entry.
- **Leader — post / edit / delete events** and **edit the community** (`POST`/`PATCH`/`DELETE`
  per [`api/communities.md`](../api/communities.md)). These affordances appear only when
  `your_role:"leader"`.

## Navigation

- Title bar → context selector (back to My Friends, a squad, another community, Discover).
- Event card → thread drawer.
- "Bring friends" → switches context to My Friends with the composer open.

## Principles

**Inherited:**

- [Public attendance is opt-in and tiered](../principles.md#public-attendance-is-opt-in-and-tiered)
  — the Going / Show-name toggles and the headcount/face-pile split.
- [Private-first](../principles.md#private-first-public-never-touches-the-friends-surface) —
  public events exist only in this context; they reach friends only via the bridge.
- [Lower the stakes](../principles.md#lower-the-stakes-of-participation) — RSVP is light and
  defaults to anonymous; being publicly seen is never forced.

## Local

- **Leaders broadcast, followers consume.** In a community context the timeline is one-to-
  many: only leaders post events; everyone else RSVPs and threads. This is the crisp
  contrast with squads (where everyone posts) and matches how real orgs/venues operate.
  *(Promote to principles.md if it starts governing specs beyond communities.)*
