# Behavior: Ideas → Activities Lifecycle

## Rule

An idea and an activity are **two states of one record**, not two objects. A record is born
an **idea** (tentative) and becomes a confirmed **activity** when its **captain** locks a
time and place. The same `id` persists across the transition.

## Applies To

`screens/friends-timeline.md`, `screens/squads.md`, `behaviors/thread-drawer.md` (the vote
bar + "Lock it in" CTA), `api/ideas-activities.md`.

## Details

- **Idea state:** has an activity type (required), optional time/location **options**, an
  `allow_suggestions` flag, an audience, and accumulates **responses** and **votes**.
- **Captain** = the proposer. Only the captain may confirm.
- **Confirm:** the captain picks the final time + location (typically the leading voted
  options) → `POST /v1/ideas/:id/confirm` → `state: confirmed`, `confirmed_time` /
  `confirmed_location` set. Surfaced as a "Lock it in" CTA in the idea's vote bar.
- **Voting** only exists in the idea state and only when there are options (and suggestions,
  if `allow_suggestions`). Confirming resolves it.
- **Brought-along plans** follow the *same* arc, but time/place are **pre-fixed by the
  referenced community event**, so the only open variable is "are we doing it." The confirm
  CTA reads "Time & place set by the event"; confirming promotes it to an activity **linked
  to the community event** (it never lingers as a perpetual idea). See
  [bring-friends-bridge](bring-friends-bridge.md).

## Principles

**Inherited:**

- [Lower the stakes](../principles.md#lower-the-stakes-of-participation) — "idea" is the
  deliberately lighter framing that precedes commitment; confirmation is the captain's, not
  a group obligation.
