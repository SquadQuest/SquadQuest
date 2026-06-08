# Behavior: Response System

## Rule

A person responds to an idea/activity with one of three values — **"I'm in!"**,
**"Interested"**, **"Next Time"**. There is **no decline**: not responding is the dismiss.

## Applies To

Every idea/activity card and thread header (`screens/friends-timeline.md`,
`screens/squads.md`, `behaviors/thread-drawer.md`), `api/ideas-activities.md` (`PUT/DELETE
/v1/ideas/:id/response`).

## Details

- Values: `in` (committed), `interested` (want to, not committing), `next_time` (not this
  time, keep me in the loop). Absence = passive dismiss (no visible "declined" state to
  anyone).
- **Inline + collapsing:** an unresponded item shows all three buttons in a row beneath the
  card. After responding, the row **collapses to a single chip** showing the chosen
  response; tapping the chip re-expands to change it.
- Responses are visible to the item's audience (counts; the captain/participants can see who
  responded). Clearing a response (DELETE) returns to the unresponded state.
- Community-event attendance is a **different** control (the going/public visibility
  gradient), not this three-value response. See
  [communities](../screens/communities.md).

## Principles

**Inherited:**

- [Lower the stakes](../principles.md#lower-the-stakes-of-participation) — three soft
  options and a no-friction passive dismiss; never force a visible "no".
