---
status: planned
depends: [v2-activity-types-community]
specs: []
issues: []
pr:
---

# Plan: v2 activity types — browse by category (UI + richer category model)

> **Backlog stub.** Third slice of the taxonomy arc. The seed gave every official topic a single
> `category` string (Sports/Outdoors/Games/Food & Drink/Arts/Music/Social/Civic); this slice builds
> the **browse-by-category** surface and, if needed, a richer category model.

## Scope (anticipated)

**In:**

- A **browse/discover** surface: pick an activity type by category (the ctufts v7 prototype's
  category grid + search is the design reference), rather than scrolling one long list.
- Category assignment for **community** types (the create slice leaves community `category` null;
  here, infer/prompt a category, or let the merge/admin flow set it).
- Possibly a **multi-category** model (the v7 prototype had topics in 2+ categories, e.g. Trail
  Running ∈ Sports+Outdoors) — promote `category` string → a `topic_category` join if the single
  string proves limiting.

**Out:** the create + dedup mechanics (community slice); merge/admin (merge slice); semantic
"related topics" / similarity browse (a later nicety from the v7 prototype's `_relatedMap`).

## Anticipated spec surface (specs-first at pickup)

- `specs/data-model.md` — multi-category join (if adopted) over the current single `category`.
- `specs/api/topics.md` — list grouped/filtered by category.
- `specs/screens/…` — the category browse screen + its entry from the composer.

## Risks / unknowns

- **Single string vs join:** only promote to a join if multi-category is actually needed — the v7
  prototype suggests it, but YAGNI until the browse UX demands it.
- Community-type categorization is fuzzy; may lean on the merge/admin flow to assign rather than
  asking end users at create time (keep create frictionless — see the community slice).
