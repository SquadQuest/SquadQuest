---
status: planned
depends: [v2-wants-sharing]
specs: []
issues: []
pr:
---

# Plan: v2 wants — overlap alerts ("you both want X")

> **Backlog stub.** The third slice of wants (split from the original `v2-wants`). Depends on
> `v2-wants-sharing` (only *shared* wants are ever compared). Surfaces a gentle affordance when two
> accepted friends share a matching want, deep-linking into promote/compose.

## Scope

**In (anticipated):**

- **Overlap detection** among **accepted friends' shared wants**: start dumb and correct — exact
  `topic` match, plus normalized-title equality. Layer fuzziness later.
- A gentle in-app **affordance** ("You and Sam both want to try wakeboarding — plan it?") that
  deep-links into promote/compose, pre-filling the shared topic.
- Compute on read or on create/share (cheap at current scale); revisit if it needs realtime.

**Out:** ML-grade matching; push delivery (in-app first — rides on whatever realtime/notifications
land); overlap across non-friends.

## Implements (anticipated — specs first at pickup)

- `specs/behaviors/want-overlap.md` (new) — the matching rule, alert semantics, and the **privacy
  firewall**: only *shared* wants are ever compared; private wants are never read or revealed; the
  accepted-friend gate is respected.
- `specs/api/wants.md` — an overlap query/endpoint.
- `specs/screens/` — where the affordance appears (wants list / friend profile / a nudge surface).

## Validation (sketch)

- [ ] overlap returns only shared-vs-shared matches among accepted friends; private wants never
      participate; the affordance deep-links into a pre-filled compose. Tests. CI.

## Risks / unknowns

- **Privacy firewall is the sharp edge:** matching must never compare or reveal private wants, and
  must respect the accepted-friend gate. Spec it explicitly before code.
- **Delivery surface:** in-app affordance now; push waits on the realtime/notifications story
  (`v2-realtime-sse` and beyond).

## Notes

(closeout)

## Follow-ups

(closeout)
