---
status: planned
depends: [v2-wants-core]
specs: []
issues: []
pr:
---

# Plan: v2 wants — mutual-wants signal (someday)

> **Backlog stub, low priority.** With invites (in `v2-wants-core`) as the primary mechanism, direct
> matching of *un-connected* wants is a weak secondary signal — the user said as much: "it's too
> hard to make alignment happen with disconnected mutual wants; a direct invite is strong." This
> plan is the optional nicety: when two accepted friends **independently** have wants with the same
> `topic` (neither invited the other), surface a gentle nudge — "you and Sam both want to try
> wakeboarding — invite them?" — that deep-links into inviting/promoting.

## Scope

**In (anticipated, if built):**

- Detect mutual wants among **accepted friends**: exact `topic` match (start dumb + correct),
  optionally normalized-title equality. Both wants must be the friends' own; this never reads a
  third party.
- A gentle in-app affordance that deep-links into **inviting** that friend to the existing want (or
  promoting) — turning a passive coincidence into the strong, explicit invite flow.

**Out:** push delivery (in-app only; rides on the realtime/notifications story); ML matching;
matching across non-friends; anything that reveals a want the owner hasn't acted on to the other
party without consent.

## Implements (anticipated — specs first at pickup)

- `specs/behaviors/want-overlap.md` (new) — the matching rule + the **privacy firewall**: a match is
  computed only between two accepted friends' *own* wants and only ever surfaces as a *suggestion to
  invite*, never by exposing one friend's want to the other directly. The nudge must not leak want
  contents before an invite exists.

## Risks / unknowns

- **Privacy firewall is the sharp edge** — a coincidence nudge must not reveal that a specific friend
  has a specific want until the normal invite makes it explicit. Spec the disclosure boundary before
  any code.
- **Weak signal / alert fatigue** — this is why it's deprioritized below invites; only worth building
  if testing shows people want it.

## Notes

(closeout)

## Follow-ups

(closeout)
