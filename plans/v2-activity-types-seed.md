---
status: done
depends: []
specs:
  - specs/data-model.md
issues: []
pr: 462
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

- [x] `topic.kind` column exists (migration 0008); seed migration 0009 inserts 23 curated official
      topics; re-run is a no-op (WHERE NOT EXISTS on label). `topics-seed.test.ts` asserts 23
      official rows + idempotency. `bun test` 63 pass; type-check clean.
- [x] verified end-to-end: `bin/reset-db` → a fresh DB migrates to exactly 23 official topics, so
      composing an idea / creating a want now has types (blocker cleared). Prod gets them via
      migrate-on-startup on deploy.

## Notes

PR #462. The seed is a **hand-written data migration** (0009), not drizzle-generated — so its
journal entry was added manually. Idempotent via `WHERE NOT EXISTS` on label (no unique constraint
needed). Verbs absent in the ctufts prototype were given natural readings ("Go Rock Climbing",
"Grab Coffee", etc.); labels are intentionally low-stakes — they'll be refined by the taxonomy
work + the v1-DB scan.

## Follow-ups

- **Tracked — `v2-activity-types-taxonomy`:** the full official/community model (create-on-the-fly,
  categories, review/merge), which also folds in the v1 topics-DB export (needs Chris to export the
  live Supabase topics). The labels/verbs seeded here are provisional until then.
