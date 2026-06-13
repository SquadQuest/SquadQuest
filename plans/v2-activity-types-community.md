---
status: in-progress
depends: [v2-activity-types-seed]
specs:
  - specs/data-model.md
  - specs/api/topics.md
issues: []
pr:
---

# Plan: v2 activity types — community create (slice 1 of the taxonomy)

> First slice of the taxonomy arc (the larger `v2-activity-types-taxonomy` was split at pickup —
> see `v2-activity-types-merge` + `v2-activity-types-browse` for the deferred halves). This slice
> lets users **create community activity types** — on the fly while composing, or via a dedicated
> create — alongside the curated official set, with light dedup so the obvious near-dupes don't
> pile up. Specs first (this plan's first PR), then backend, then client.

## Scope

Two tiers already exist in the schema (`topic.kind ∈ {official, community}`, seeded official set).
This slice makes the **community** tier real and user-creatable.

**In:**

- `topic.created_by` → profile (null for official); community types are user-created.
- **Create:** `POST /v1/topics` (dedicated) **and on-the-fly** from the composer/want editor — when
  the user types a type that doesn't exist, create a `community` topic and use it in one step.
- **Dedup-on-create (normalized-match reuse):** normalize the label (lowercase, trim, collapse
  whitespace, strip surrounding punctuation) and if it matches an existing topic (official *or*
  community), **return that one** instead of inserting a near-dupe. Fuzzy/semantic merge is the
  admin tool's job (`v2-activity-types-merge`).
- **Listing:** `GET /v1/topics` becomes **official-first** (official before community, then
  alphabetical) + `?search=` (normalized substring) so the picker surfaces the curated set first.

**Out (later slices):** the admin **review/merge** backend + `merged_into` tombstones
(`v2-activity-types-merge`); a **browse-by-category** UI + multi-category model
(`v2-activity-types-browse`); fuzzy/semantic dedup; moderation/abuse tooling beyond basic
label validation.

## Implements (specs written first)

- `specs/data-model.md` — `topic.created_by`; the normalized-label reuse rule (no hard DB unique
  yet — normalization + lookup in the service, since official labels may legitimately coexist with
  differently-cased history; revisit a unique index in the merge plan).
- `specs/api/topics.md` (new) — list (official-first + search), `POST /v1/topics` (create with
  normalized reuse), and the on-the-fly contract (composer accepts a new label → topic created).

## Approach

- **Backend:** `topic.created_by` column + migration; a `TopicService.findOrCreate(label, by)`
  doing normalized lookup → reuse-or-insert (`kind=community`, `created_by=by`); `POST /v1/topics`;
  `GET /v1/topics` ordered `kind=official desc, label asc` with optional `?search`. Extend
  `createIdea`/want-create to accept either `activity_type_id` **or** a new `activity_type_label`
  (the on-the-fly path → findOrCreate). Keep `noun`/`verb` derivable from the label for community
  types (verb optional → label is the source of truth).
- **Client:** the topic picker gains an "add new" affordance (type-ahead with a "+ Create
  '<text>'" row); official-first ordering + search. Wire into `compose_idea_screen` and the want
  editor. On create-on-the-fly, post with the label; the server returns the resolved topic.

## Validation

- [ ] backend: create a community topic (dedicated + on-the-fly); normalized dupe returns the
      existing one (no new row); list is official-first + search filters; `created_by` set for
      community, null for official. `bun test` + type-check; CI.
- [ ] client: composer/want editor can pick an official type OR create a new one inline; list shows
      official first. `flutter analyze` + widget tests; CI.
- [ ] (on-device, post-merge) create "Disc Golf" on the fly, post an idea with it; re-typing
      "disc golf" reuses it.

## Risks / unknowns

- **Dedup scope:** normalized-match only this slice (lowercase/trim/punctuation) — deliberately not
  fuzzy/semantic (that's the merge plan). Don't over-build it here.
- **noun/verb for community types:** the schema requires `noun`+`verb` NOT NULL. For a free-text
  community label, derive sensibly (e.g. whole label as noun, empty/`""`-safe verb) rather than
  forcing the user to fill a noun-verb form — keep create frictionless. Settle in the spec.
- **On-the-fly contract:** `createIdea` taking either an id or a label must stay backward-compatible
  with the existing id-only callers (bring-friends, wants-promote).

## Notes

(closeout)

## Follow-ups

(closeout)
