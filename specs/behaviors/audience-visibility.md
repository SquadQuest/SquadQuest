# Behavior: Audience Visibility

## Rule

The user must always be able to tell **who will see** what they're about to post or how they
respond, shown **at the moment of action** — not in settings, not after the fact.

## Applies To

Every composer and input area across contexts (`screens/friends-timeline.md`,
`screens/squads.md`, `screens/communities.md`, `behaviors/thread-drawer.md`,
`behaviors/context-selector.md`).

## Details

A persistent, contextual **audience indicator** sits above the input and updates with what
the user is about to do:

- **My Friends:** "Your friends see your ideas · threads are private"
- **Squad:** "Visible to <Squad> members"
- **Idea composer open:** "This idea will be shared with all your friends" / "…with <Squad>"
- **Bringing friends to an event:** "Sharing with all friends · about a <Community> event"
- **Community context:** read-only follower banner ("Following · only leaders post events")
- **Thread:** "Only participants in this thread can see replies"

It is muted but legible (a small lock/eye/people icon), reinforcing control without alarm.

## Principles

**Inherited:**

- [Audience clarity at the moment of action](../principles.md#audience-clarity-at-the-moment-of-action)
  — this behavior *is* that principle, made concrete.
- [Private-first](../principles.md#private-first-public-never-touches-the-friends-surface) —
  the indicator is also the constant reassurance that the friends surface stays private.
