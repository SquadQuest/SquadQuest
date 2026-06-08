# Behavior: Bring-Friends Bridge

## Rule

A user brings friends to a **community event** by posting a **friends-scoped idea that
embeds the event** — not by sharing the public event into the friends timeline. The public
event stays community-owned; what lands on My Friends is a private envelope around it, whose
**thread is the private logistics room**.

## Applies To

`screens/communities.md` (the "Bring friends" action), `screens/friends-timeline.md` (the
resulting embedded-event card), `behaviors/thread-drawer.md`, `api/ideas-activities.md`
(`POST /v1/ideas` with `community_event_id`).

## Details

- **Trigger:** "Bring friends" on a community event → switch to My Friends with the idea
  composer pre-filled from the event (activity type; the event attached as a read-only
  reference chip) → a destination picker (My Friends, or one of your squads).
- **Result:** a normal `activity` (idea) with `event_ref` set and time/place fixed by the
  event. It follows the standard [idea→activity arc](ideas-activities-lifecycle.md) — born
  as a commitment or confirmed via the event-derived time/place — and **never lingers as a
  perpetual idea**; it lands as an activity **linked to** the community event (a separate,
  friends-scoped record, not the public event itself).
- **Two linked records:** the community event (community-owned, public, the canonical
  time/place + recurrence + public headcount) and the brought-along activity (yours,
  friends-scoped, with the private thread). Multiple friend groups can each spin up their
  own brought-along activity linked to the same event.
- **Attendance coupling:** a friend who responds "I'm in" to the brought-along idea is
  counted in the event's **anonymous** headcount (they're genuinely attending) but is
  **never** added to the public face-pile without an explicit public RSVP. See
  [public attendance is opt-in and tiered](../principles.md#public-attendance-is-opt-in-and-tiered).
- **Growth loop:** friends discover communities by seeing each other bring events into the
  friends timeline → tap the embedded event → follow.

## The firewall invariant

**The My-Friends composer only ever emits friends-scoped ideas; public exposure of self or
event requires explicit community-context or public-RSVP action.** What crosses the fence
from a friends-scoped action is at most an anonymous +1 to a headcount — never identity.

## Principles

**Inherited:**

- [Private-first](../principles.md#private-first-public-never-touches-the-friends-surface) —
  the firewall invariant above is this principle at the bridge; the event is read-only
  context inside a private idea.
- [Public attendance is opt-in and tiered](../principles.md#public-attendance-is-opt-in-and-tiered)
  — the anonymous-count-yes / public-identity-no coupling rule.
