# API: Topics (activity types)

The noun-verb activity taxonomy chosen when composing an idea or creating a want (the `topic`
entity — see [`data-model.md`](../data-model.md)). Two tiers: **official** (curated, take
preference everywhere) and **community** (user-created). Authenticated.

## Serialized topic

```jsonc
{ "id": "uuid",
  "noun": "Hiking",
  "verb": "Go",
  "label": "Go Hiking",
  "kind": "official" | "community",
  "category": "Outdoors" | null }
```

## GET /v1/topics

List activity types for the composer/picker. **Official-first**: official types before community,
then alphabetical by label — so the curated set surfaces first.

- **Query:** `?search=` — normalized substring match on the label (case-insensitive).
- **Response:** `200 { "items": [<topic>…] }`.

## POST /v1/topics

Create a **community** activity type. Used by the dedicated "create a type" flow; the composer's
on-the-fly path (below) is the common case.

- **Request:** `{ "label": "string" }` — required, non-empty after trimming (`400 label_required`).
- **Normalized-label reuse:** the label is normalized (lowercase, trim, collapse internal
  whitespace, strip surrounding punctuation); if it matches an existing topic (official **or**
  community), that topic is returned with **`200`** (no duplicate created). A genuinely new label
  inserts a `community` topic (`kind:"community"`, `created_by` = caller) and returns **`201`**.
- **Response:** `201 <topic>` (created) or `200 <topic>` (reused).
- `noun`/`verb` for a community type are derived from the label (the label is the source of truth);
  the user is not asked to fill a noun-verb form — creation stays frictionless.

## On-the-fly create (from the composer)

Composing an idea / creating a want accepts **either** a known `activity_type_id` **or** a new
`activity_type_label`:

- [`POST /v1/ideas`](ideas-activities.md) and `POST /v1/wants` ([`wants.md`](wants.md)) take an
  optional `activity_type_label` as an alternative to `activity_type_id`. When a label is given, the
  server runs the same **find-or-create** (normalized reuse → existing, else new community topic)
  and uses the resolved topic. Exactly one of id / label is required.
- This means a user can type a brand-new activity type and post in one step; re-typing the same
  thing later reuses the topic rather than spawning a near-duplicate.

## Notes

- All dedup here is **normalized-match only**. Fuzzy/semantic merging, merging community types into
  official ones, and the `merged_into` tombstone are the **review/merge** stage — see
  [`plans/v2-activity-types-merge.md`].
- Browse-by-category is a later surface (`plans/v2-activity-types-browse.md`); this spec is the flat
  official-first list + search.

## Principles

**Inherited:**

- [Lower the stakes of participation](../principles.md#lower-the-stakes-of-participation) — letting
  a user type a new activity type and go (rather than forcing a pick from a fixed list or a
  noun-verb form) keeps the moment of composing friction-free; the curated official set stays
  authoritative by listing first.
