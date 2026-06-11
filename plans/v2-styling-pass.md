---
status: planned
depends: []
specs: []
issues: []
pr:
---

# Plan: v2 styling pass (re-port the polished mock UI)

> **Backlog stub** (`status: planned`). The whole v2 client was built **functionality-first,
> styling deferred** — nearly every done client plan says so. This is where that debt gets paid:
> bring the screens up to the polished v2 mock UI. Best done once the feature surface stops
> moving. Specs are largely unaffected (specs declare *what*, not visual design — see
> `principles.md`/SpecOps); this is a UI/theme effort, not a contract change.

## Scope

Re-port the polished v2 mock UI (cards, thread drawer, composer, timeline tiles, context
selector, communities) from the `v1` branch's `lib/v2` mock into the live client, replacing the
current plain/functional screens. Establish shared theme constants (color, type, spacing) and
reusable widgets so it's consistent, not per-screen one-offs.

**In (anticipated):**

- Theme/constants foundation (`constants/` — colors, typography, spacing) + a few shared widgets
  (activity card, message tile, section headers, the thread drawer surface).
- Screen-by-screen restyle: timeline (friends/squad/community), activity detail, compose, squads,
  communities + leader forms, friends/People, welcome, thread view.
- Wire in the **photo** surfaces now that they exist (avatars on tiles/face-piles, community
  cover images, message thumbnails).

**Out:** new behavior or endpoints (pure presentation); animations/motion polish beyond the mock;
icon/illustration asset production.

## Implements

No API/behavior spec changes expected. If a screen spec's *Display Rules* turn out to under- or
mis-specify what the mock shows, fix that spec first (per SpecOps) — but the bulk is visual.

## Approach (rough — refine at pickup)

- Pull the `lib/v2` mock from the `v1` branch as the visual reference; lift its theme + widget
  decomposition rather than re-inventing.
- Land the theme/constants + shared widgets first, then restyle screens incrementally (each screen
  is independently shippable — don't block on a big-bang).
- Verify against each screen spec's Display Rules so styling doesn't drift behavior.

## Validation

- [ ] theme constants + shared widgets in place; screens restyled to the mock; `flutter analyze`
      + widget tests stay green.
- [ ] each restyled screen still satisfies its spec's Display Rules (no behavior regressions).

## Risks / unknowns

- Large surface; **must stay incremental** (per-screen PRs) — a single mega-restyle PR is
  unreviewable and risky.
- Easy to accidentally change behavior while restyling — keep the spec's Display Rules as the
  acceptance check for each screen.
- The `lib/v2` mock lives on the `v1` branch; porting means reading across branches.
- Best sequenced **after** the remaining feature/UI work (message attachments) so screens aren't
  restyled then immediately re-touched.

## Notes

(closeout)

## Follow-ups

(closeout)
