---
status: in-progress
depends: []
specs:
  - specs/data-model.md
issues: []
pr:
---

# Plan: v2 seed curated official activity types (unblock)

> **Live blocker:** `GET /v1/topics` reads an empty table in every fresh DB — there is no seed —
> so nothing in the app that requires an activity type (ideas, wants) can be created. This plan
> ships a small curated **official** seed to unblock all real testing. The full official/community
> model (create-on-the-fly, categories, review/merge, v1-DB enrichment) is a separate, larger
> effort — see `v2-activity-types-taxonomy`.

## Scope

**In:**

- Add `topic.kind ∈ {official, community}` (default `official`). Official types are curated and
  take preference everywhere; community types arrive with the taxonomy plan.
- A seed migration inserting ~23 curated **official** topics (noun/verb/label) drawn from the
  `origin/ctufts/topic-exploration` v7 prototype (Sports / Outdoors / Games / Food & Drink / Arts /
  Social). Idempotent (no duplicate on re-run).
- Update `specs/data-model.md` topic entry to document `kind`.
- A test asserting the seed loaded + `GET /v1/topics` returns them.

**Out:** categories on `topic` (taxonomy plan); user/community-created types + create-on-the-fly
(taxonomy plan); the v1 topics-DB scan (needs Chris's export — feeds the *curated set* later, not
this unblock); semantic search / related-topics (prototype-only, later).

## Approach

- `kind` is a pgEnum column, additive; existing rows (none in prod yet) default `official`.
- Seed via a hand-written SQL migration (`INSERT … ON CONFLICT DO NOTHING` keyed on label) so it's
  reproducible and runs on deploy via migrate-on-startup — no separate seed script to invoke.
- Verbs absent in the prototype are assigned natural readings (e.g. "Go Rock Climbing", "Play Board
  Games"); labels are low-stakes and refined later by the taxonomy work + v1 scan.

## Validation

- [ ] `topic.kind` column exists; seed migration inserts the curated official set; re-running is a
      no-op. `GET /v1/topics` returns them. `bun test` + type-check; CI.
- [ ] (post-merge) composing an idea / creating a want offers the seeded types — the blocker clears.

## Notes

(closeout)

## Follow-ups

(closeout)
