---
status: in-progress
depends: [v2-backend-stage2-activities, v2-friends-and-onboarding]
specs:
  - specs/data-model.md
  - specs/api/wants.md
  - specs/screens/wants.md
  - specs/api/profile.md
issues: []
pr:
---

# Plan: v2 wants — core (personal backlog → promote to idea)

> Core slice of the wants feature (the larger `v2-wants` was split at pickup — see
> `v2-wants-sharing` + `v2-wants-overlap` for the deferred halves). This plan: a user's own
> backlog of "ready to go" activities, plus one-tap promote into a real idea via the existing
> composer. Specs are written first (this plan's first PR), then backend, then client.

## Scope

A personal **backlog of activities a user wants to do** — generic ("go wakeboarding") to specific
("check out Wonderland Garden in Fishtown"). The entity is a **`want`** (UI: "Want to do"). Each
carries a real noun-verb `topic` (same taxonomy as an activity), so it's **ready to go** —
promoting is one tap.

**Model (resolved):** a want is its **own `want` entity, NOT a state of `activity`**. The deciding
reason is **ongoing aspirations**: an `activity` is event-shaped and confirms to a time+place,
whereas an `ongoing` want never confirms and **spawns activities repeatedly**. An activity can't be
a factory of itself, so wants sit one layer above. Promote = **spawn** a new activity
(back-linked via `from_want_id`), never flip a row.

**In:**

- A `want` entity: **required `topic`**, optional `title`/`location`/`notes`; `owner`;
  **`visibility {private | shared}`** (the column ships now; *browsing* shared wants is
  `v2-wants-sharing`); **`kind: one_shot | ongoing`**; created/updated/`archived_at`.
- CRUD + a list view of **your own** wants (private + shared).
- **Promote = spawn:** one tap opens the existing composer **pre-filled** from the want (topic, and
  title/location as option hints) → posts through any channel the user can already publish to →
  creates an `activity` with `from_want_id` set. A `one_shot` want **archives** on promote
  (`archived_at` set); an `ongoing` want persists and can spawn again.

**Out (this slice → later plans):** friends browsing each other's shared wants (`v2-wants-sharing`);
overlap detection + alerts (`v2-wants-overlap`); ranking; collaborative lists.

## Implements (specs written first, this plan's first PR)

- `specs/data-model.md` — the `want` entity (own table, not an `activity` state): required `topic`,
  `{private|shared}`, `kind: one_shot | ongoing`, `archived_at`; plus `activity.from_want_id`
  back-link. Record *why* it's its own entity (the factory argument).
- `specs/api/wants.md` (new) — list/create/update/delete own wants + promote.
- `specs/screens/wants.md` (new) + a profile-screen entry point; compose pre-fill from a want.
- `specs/api/profile.md` — note the wants entry point (shared-wants *read* surface deferred to
  `v2-wants-sharing`).

## Approach

- **Backend:** `want` Drizzle table + migration; `WantService` (CRUD scoped to owner; `promote`
  calls the existing `ActivityService.createIdea` then sets `from_want_id`, and archives the want
  when `kind = one_shot`). Routes under `/v1/wants`. `from_want_id` is a nullable uuid on
  `activity` (no behavior change to existing creates).
- **Promote reuses createIdea / the composer** — no parallel publish path. Promote *spawns*; it
  never mutates the want except setting `archived_at` for `one_shot`.
- **Client:** `Want` model + repo + providers; a wants list screen (own private+shared, with a
  visibility toggle + kind toggle on add/edit); entry point from the profile screen; promote routes
  into `ComposeIdeaScreen` pre-filled (extend it to accept an optional want seed).
- Visibility column ships now but is **owner-only-enforced**; only the owner reads their wants until
  `v2-wants-sharing` adds the friend-read surface. (Private-first: shared ≠ public.)

## Validation

- [ ] backend: CRUD scoped to owner (you only ever read/modify your own); promote spawns a real
      idea via the existing path with `from_want_id` set; `one_shot` archives on promote, `ongoing`
      persists + can spawn again. `bun test` + type-check; CI.
- [ ] client: wants list (own); add/edit with visibility + kind; promote → composer pre-filled →
      publishes to any channel. `flutter analyze` + widget tests; CI.
- [ ] (on-device, post-merge) add a want, promote it, confirm it posts and (one_shot) archives.

## Risks / unknowns

- Post-promote policy is decided: `one_shot` → `archived_at` set (drops off the active list);
  `ongoing` → stays. The list view filters archived by default.
- Composer pre-fill: `ComposeIdeaScreen` currently seeds from `broughtEvent` only — adding an
  optional want seed must stay additive and not disturb the bring-friends path.
- Don't let the `visibility` column imply sharing works yet — enforce owner-only reads in this
  slice so nothing leaks before `v2-wants-sharing` builds the real gate.

## Notes

(closeout)

## Follow-ups

(closeout)
