# Screen: Squad Timeline

A squad context — a **closed**, persistent, named group (the evolution of the group text).

## Route

Selected from the [context selector](../behaviors/context-selector.md) (a Squad entry).
Title bar shows the squad badge + name, tappable to switch.

## Data Requirements

- `GET /v1/squads/:squadId/timeline` — a heterogeneous, interleaved feed of serialized
  `activity` (ideas/activities) **and** `message` (free text + photos) objects, each tagged
  with `type`. Requires membership. See [`api/timeline.md`](../api/timeline.md),
  [`api/messages.md`](../api/messages.md).

## Display Rules

- Same chat-like layout as My Friends (bottom input, scroll up), **but** free-text messages
  **are** allowed here alongside ideas/activities.
- Messages render as author line + text and/or photo attachments (photo-only allowed),
  with a reply/thread indicator when they have replies.
- Ideas/activities render exactly as on My Friends (compact cards, inline response, vote
  indicator), scoped to the squad.

## Actions

- **Post a message** (text and/or photos) to the squad timeline — `POST /v1/squads/:id/messages`.
- **Compose an idea** scoped to the squad (the same unified composer; scope = this squad).
- **Respond / vote / confirm** on squad ideas/activities (same lifecycle).
- **Open any item** → [thread drawer](../behaviors/thread-drawer.md) (a message thread has a
  simpler header than an idea/activity thread; no voting).
- Captain-only membership management is **deferred** (later plan).

## Navigation

- Title bar → context selector.
- Item → thread drawer.

## Principles

**Inherited:**

- [Group text, not social feed](../principles.md#group-text-not-social-feed) — a squad *is*
  the group text, made durable; free text is first-class here.
- [Audience clarity at the moment of action](../principles.md#audience-clarity-at-the-moment-of-action)
  — the composer/banner states "Visible to <squad> members".

## Local

- **Squads are closed; everyone posts.** Membership is captain-controlled and the timeline
  is many-to-many (any member posts text + ideas) — the inverse of a community's
  leaders-broadcast model. The context selector and audience copy must keep the two
  visibly distinct.
