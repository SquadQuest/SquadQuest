---
status: planned
depends: [v2-activity-types-seed]
specs: []
issues: []
pr:
---

# Plan: v2 activity-types taxonomy (official + community, create + review/merge)

> **Backlog stub** — the full model behind activity types, beyond the curated official seed
> (`v2-activity-types-seed`). Captures intent; specs written first at pickup.

## Vision (from the user)

Two tiers of activity type:

- **Official** — curated, high-quality, take **preference everywhere** (surfaced first, canonical
  labels). Seeded + maintained by the team.
- **Community / user** — created by users, either **on the fly** while composing (type a new one
  and go) or via a dedicated flow. Lower precedence; visible but clearly secondary.

A backend **review/merge process** lets the team curate the community tier: merge near-duplicate
community types into each other and/or **into official types** (e.g. "bball" + "Hoops" → official
"Play Basketball"), with references repointed so nothing breaks. Official always wins.

## Data sources for the curated set

- **`origin/ctufts/topic-exploration`** v7 prototype — 23 topics × 6 categories with verbs +
  semantic-similarity + related-topic maps (a starting structure for categories + search/merge).
- **The v1 topics database** — a large, messy, organically-grown real corpus. "The way I built them
  sucked and people went wild, but it IS a good data source." **Needs a Chris export** (live
  Supabase, not in-repo) — drives both the curated official set *and* the merge/dedupe heuristics.

## Anticipated spec surface (specs-first at pickup)

- `specs/data-model.md` — `topic` gains `category` (or a topic↔category join), `created_by`
  (null for official), `merged_into` (a tombstone pointer for merged community types so references
  resolve to the survivor); `kind` already shipped in the seed plan.
- `specs/api/topics.md` (new) — list (official-first, search), **create** (community), and the
  on-the-fly create path from the composer.
- `specs/behaviors/topic-curation.md` (new) — the review/merge model: dedupe heuristics
  (exact/normalized/semantic), merge = repoint references + tombstone, official-takes-preference,
  who can merge (admin/leader?).
- `specs/screens/…` — composer create-on-the-fly affordance; a manage/browse-by-category surface;
  (admin) a review/merge queue.

## Risks / unknowns

- **Merge integrity:** activities/wants/subscriptions reference `topic_id`; merging must repoint or
  tombstone-resolve so no row dangles. Spec the reference-repoint rule explicitly.
- **On-the-fly create vs spam:** frictionless creation invites near-duplicates — that's expected
  (the review/merge process is the cleanup), but guard against trivially-empty/abusive labels.
- **v1 import is messy** — treat it as a *source to curate from*, not a bulk import; most of it
  should inform official types or seed community types, not land verbatim.
- Likely **splits at pickup** (e.g. create-community-types; categories + browse; the review/merge
  admin backend) — it's a large arc.

## Notes / Follow-ups

(closeout)
