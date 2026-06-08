# API: Timeline (feeds)

The read endpoints behind the three contexts of the context selector (My Friends / a Squad
/ a Community). All cursor-paginated per [conventions](conventions.md). Authenticated.

## GET /v1/timeline/friends

The **My Friends** global feed: ideas/activities from everyone the user is accepted-friends
with (and their own). **Only ideas and activities — never free-text messages.**

- **Query:** `limit`, `before` (cursor).
- **Response:** `{ "items": [<activity>…], "next_cursor": … }` — each item is a serialized
  **activity** (idea or confirmed; see `api/ideas-activities.md` for the shape, incl.
  inline `your_response`, vote summary, and embedded `event_ref` for brought-along plans).
- Items a brought-along idea references a community event via `event_ref`.

## GET /v1/squads/:squadId/timeline

A squad's feed: ideas/activities **and** free-text messages, interleaved.

- **Response:** `items` are a heterogeneous list of serialized `activity` and `message`
  objects (each tagged with a `type`), newest-last, cursor-paginated.
- Requires membership; non-members → `403 not_member`.

## GET /v1/communities/:communityId/timeline

A community's broadcast feed: **community events only** (leaders broadcast; followers don't
post). See `api/communities.md`.

- **Response:** `items` are serialized `community_event` objects.
- Open to anyone (following not required to view); following affects notifications.

## GET /v1/stream  (SSE)

Live updates for everything the user may see (their friends feed, joined squads, followed
communities). Typed events (`activity.created`, `activity.confirmed`, `response.changed`,
`vote.changed`, `message.created`, `rsvp.changed`, …), each carrying the affected resource
in its serialized wire shape.

- Enhancement only — clients render from the fetch endpoints above and use the stream to
  patch live. See [realtime is an enhancement](../principles.md#realtime-is-an-enhancement-not-a-dependency).

## Notes

- The friends feed is the place [private-first](../principles.md#private-first-public-never-touches-the-friends-surface)
  is enforced on read: it never returns public/community content directly — community events
  only reach a friend's attention via a brought-along idea (`event_ref`).
- Audience filtering (which friends/people may see a given idea) is enforced server-side.

## Principles

**Inherited:**

- [Group text, not social feed](../principles.md#group-text-not-social-feed) — cursor
  pagination walking backward through history; newest at the bottom.
- [Private-first](../principles.md#private-first-public-never-touches-the-friends-surface) —
  the friends feed is friends-scoped only.
