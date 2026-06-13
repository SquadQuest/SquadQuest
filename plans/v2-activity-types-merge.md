---
status: planned
depends: [v2-activity-types-community]
specs: []
issues: []
pr:
---

# Plan: v2 activity types — review / merge (admin curation)

> **Backlog stub.** Second slice of the taxonomy arc. Once users can create community types
> (`v2-activity-types-community`), near-duplicates and junk accumulate by design; this is the
> backend + admin tooling to curate them: merge community types into each other and/or into
> official types, **official always winning**, with references repointed so nothing breaks.

## Scope (anticipated)

**In:**

- `topic.merged_into` → topic (tombstone pointer). A merged community topic isn't deleted; it
  points at the survivor, and reads resolve through it (so any lingering reference still works).
- **Merge operation:** repoint all references (`activity.activity_type_id`,
  `want.activity_type_id`, `community_event.activity_type_id`, `topic_subscription.topic_id`) from
  the loser to the survivor, then tombstone the loser. Official is always the survivor when an
  official is involved.
- **Dedup heuristics** to *surface candidates* (not auto-merge): exact, normalized (already in the
  community slice), and optionally semantic/fuzzy — seeded by the v1 corpus fixtures
  (`plans/references/v1-topics-export.csv`: camp/camping, dancing/dance.party, the music.* genres).
- **Admin surface:** a review queue of community types + suggested merges; who can merge (admin
  role — needs an authz tier; v2 has none yet, so this slice likely introduces a minimal admin gate).

**Out:** fully-automated merging (human-in-the-loop only); ML matching beyond simple similarity;
end-user-visible merge history.

## Anticipated spec surface (specs-first at pickup)

- `specs/data-model.md` — `topic.merged_into` + the reference-repoint invariant.
- `specs/behaviors/topic-curation.md` (new) — merge semantics (repoint + tombstone +
  official-wins), candidate heuristics, the authz gate.
- `specs/api/topics.md` — admin merge endpoint(s); read-resolution through tombstones.

## Risks / unknowns

- **Merge integrity is the whole game:** every `topic_id` reference must repoint or resolve through
  the tombstone — no dangling rows. Enumerate all four referencing tables (done above) and test each.
- **Authz:** v2 has no admin/role concept yet. This slice must introduce a minimal one (or gate on a
  hardcoded allowlist initially) — call it out before building.
- **Tombstone read-resolution** vs hard repoint: decide whether references are rewritten eagerly at
  merge time (simpler reads, heavier write) or resolved lazily through `merged_into` (cheaper merge,
  every read must follow the pointer). Lean eager-repoint + tombstone as a safety net.
