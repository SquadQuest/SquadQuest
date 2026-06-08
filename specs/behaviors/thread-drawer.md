# Behavior: Thread Drawer

## Rule

Tapping any idea, activity, community event, or squad message opens a right-side **thread
drawer** — a Slack-like thread with a rich header, the persistent voting bar (for ideas),
and the conversation. It's where arbitrary conversation and coordination happen; the main
timelines stay clean.

## Applies To

`screens/friends-timeline.md`, `screens/squads.md`, `screens/communities.md`;
`api/messages.md` (thread reads/writes), `api/ideas-activities.md` (vote/confirm).

## Details

- **Layout:** slides in from the right covering most of the screen, leaving a sliver of the
  timeline visible (floating feel). Covers the full height (over app bar + input). Scrim or
  X to close.
- **Header** adapts to the target:
  - *Idea/activity:* type, state (idea vs confirmed), the response controls, audience/members.
  - *Community event:* community + recurrence + time/place + the RSVP visibility-gradient
    controls + bring-friends.
  - *Squad message:* a simpler sender + preview header, no voting.
- **Vote bar (ideas with options only):** a **persistent** section between header and chat
  (not buried in the scroll). Collapsed = summary chips of the leading time/place; tap
  anywhere on the bar to expand the full voting detail (all options, voter avatars,
  "Suggest" when `allow_suggestions`). For brought-along ideas the bar instead shows
  "Time & place set by the event" + the captain confirm. See
  [ideas-activities-lifecycle](ideas-activities-lifecycle.md).
- **Conversation:** text + photo messages (`api/messages.md`), cursor-paginated, live via
  `GET /v1/stream`. Thread input at the bottom with its own audience indicator ("Only
  participants in this thread can see replies").

## Principles

**Inherited:**

- [Group text, not social feed](../principles.md#group-text-not-social-feed) — threads are
  the Slack-thread analog that keep arbitrary chat out of the main timeline.
- [Audience clarity at the moment of action](../principles.md#audience-clarity-at-the-moment-of-action)
  — the thread input states its private audience.
- [Realtime is an enhancement](../principles.md#realtime-is-an-enhancement-not-a-dependency)
  — the thread renders from a fetch; the stream patches in new messages/votes.
