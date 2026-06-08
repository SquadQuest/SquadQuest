# Screen: My Friends Timeline

The home screen and default context — the global view of everyone you're double-opt-in
friends with.

## Route

v2 app home (`/`), the default tab of the bottom-nav shell. Title bar reads **"My Friends"**
and is tappable to open the [context selector](../behaviors/context-selector.md).

## Data Requirements

- `GET /v1/timeline/friends` (cursor-paginated; see [`api/timeline.md`](../api/timeline.md)).
- Items are serialized **activities** (ideas + confirmed), including `your_response`, vote
  summary, `thread_count`, and `event_ref` for brought-along plans.
- Renders from the fetch; live updates patch in over `GET /v1/stream`
  ([realtime is an enhancement](../principles.md#realtime-is-an-enhancement-not-a-dependency)).

## Display Rules

- **Chat-like layout:** reverse chronological with newest at the **bottom**, scroll **up**
  for history (group-text feel, not an infinite feed). Input area pinned at the bottom.
- **Only ideas and activities appear here** — never free-text messages. (Free text lives in
  squads/threads.)
- Each item renders as a **compact, attachment-style card beneath an author line**
  (avatar + "Katie shared with all friends" + time) — not a full-width feed tile.
- **Ideas**: dashed/tentative border, lightbulb affordance, "Voting" indicator when the
  idea has time/location options.
- **Activities** (confirmed): solid border, confirmed time + location, going count.
- **Brought-along plans** (idea/activity with `event_ref`): render the referenced community
  event as an embedded reference chip inside the card. See
  [bring-friends-bridge](../behaviors/bring-friends-bridge.md).
- Each card shows the user's **inline response** state and the audience on the author line
  (see [audience-visibility](../behaviors/audience-visibility.md)).

## Actions

- **Respond inline** to an idea/activity — "I'm in!" / "Interested" / "Next Time"; collapses
  to an editable chip after responding. See [response-system](../behaviors/response-system.md).
- **Open a card** → the [thread drawer](../behaviors/thread-drawer.md) (chat, voting, rich
  header).
- **Compose an idea** from the bottom input (the unified composer; this context produces a
  friends-scoped idea only). Vote, suggest options, and (as captain) confirm happen in the
  thread / vote bar per [ideas-activities-lifecycle](../behaviors/ideas-activities-lifecycle.md).
- **Switch context** via the title bar.

## Navigation

- Bottom nav: Home (this) ↔ Interests (topics) and future tabs.
- Title-bar dropdown → a squad or community context, or Discover.
- Card → thread drawer (overlay; closes back to here).

## Principles

**Inherited:**

- [Private-first](../principles.md#private-first-public-never-touches-the-friends-surface) —
  this surface is friends-scoped only; its composer can never emit a public event.
- [Group text, not social feed](../principles.md#group-text-not-social-feed) — bottom input,
  scroll-up history, compact cards.
- [Audience clarity at the moment of action](../principles.md#audience-clarity-at-the-moment-of-action)
  — every card states its audience; the composer states where the post goes.
