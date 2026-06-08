# Behavior: Context Selector

## Rule

The title bar is tappable to switch the active context. There are three kinds: **My Friends**
(default), **Squads** (closed), **Communities** (open). Switching changes the timeline, the
title, the audience indicator, and where a composed item posts — all from one source of truth.

## Applies To

All three timeline screens (`screens/friends-timeline.md`, `screens/squads.md`,
`screens/communities.md`) and the composer (`behaviors/audience-visibility.md`).

## Details

The dropdown lists, with section headers:

- **My Friends** — the default global friends view.
- **Squads** — the user's squads (closed; everyone posts).
- **Communities** — the communities the user follows (open; leaders broadcast).
- **Discover communities** — entry point to find new communities (communities are *found*,
  not added).

Behavior:

- Selecting an entry sets the single active-context value → timeline, title, audience
  indicator, and post destination all follow it. They can never disagree.
- The bring-friends destination picker drives the **same** active-context value (selecting a
  squad there switches the view to that squad), so the feed behind the composer is the feed
  you're posting into. See [bring-friends-bridge](bring-friends-bridge.md).
- Communities cannot be a *post* destination (followers don't post events); they're a
  view/RSVP context only.

## Principles

**Inherited:**

- [Private-first](../principles.md#private-first-public-never-touches-the-friends-surface) —
  the context switch is the firewall boundary between the private friends surface and public
  community content.
- [Audience clarity at the moment of action](../principles.md#audience-clarity-at-the-moment-of-action)
  — one source of truth for context keeps title/feed/indicator/destination consistent.
