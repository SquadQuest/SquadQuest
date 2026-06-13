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
- **Manage members** → the [Squad Members](#squad-members) screen (app-bar icon, squad
  context only). Everyone can view the roster; only the captain can add members.

## Navigation

- Title bar → context selector.
- Item → thread drawer.
- App-bar manage-members icon → [Squad Members](#squad-members).

---

# Squad Members

The roster of a squad, and the captain's affordance to grow it.

## Route

`/squads/:squadId`. Reached from the squad timeline's app-bar manage-members icon (shown only
for a squad context).

## Data Requirements

- `GET /v1/squads/:squadId` — `{ id, name, members: [{ id, first_name, photo, role }] }`,
  where `role ∈ {captain, member}`. Requires membership (404 otherwise).
- The captain affordance also reads the viewer's accepted friends
  (`GET /v1/friends`) to offer non-members.

## Display Rules

- The roster lists every member (avatar + name), the captain marked with a **Captain** badge.
- **Captain only:** an **Add members** action. Non-captain members see the roster read-only —
  no add affordance (membership is captain-controlled per the squad's closed model).

## Actions

- **Add a member** (captain) — pick from accepted friends **not already in the squad**;
  `POST /v1/squads/:squadId/members`. Friend-gated and idempotent server-side: only accepted
  friends can be added (`not_friends` otherwise), and re-adding is a no-op. On success the
  roster and the context selector's member count refresh.
- Removing members, leaving, renaming, and captain transfer are **deferred** (later plan).

## Navigation

- Back → the squad timeline.

## Principles

**Inherited:**

- [Audience clarity at the moment of action](../principles.md#audience-clarity-at-the-moment-of-action)
  — the roster makes "who is in this squad" (and thus who sees squad posts) explicit.

**Local:**

- **Membership is captain-controlled.** Mirrors the squad's closed model (see the squad
  timeline's local principle) — only the captain mutates membership; everyone may see it.

---

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
