---
status: planned
depends: [v2-backend-stage2-activities, v2-friends-and-onboarding]
specs: []
issues: []
pr:
---

# Plan: v2 wants (personal backlog → publishable idea)

> **Backlog stub** (`status: planned`). Captures intent + rough scope only — **not** a spec.
> Per the plans protocol, the `specs:` are written *first* (their own PR) when this is picked
> up; the list under Implements is the *anticipated* spec surface, not agreed state yet.

## Scope

A personal **backlog of activities a user wants to do** — from generic ("go wakeboarding") to
specific ("check out the Wonderland Garden in Fishtown"). The entity is a **`want`** (UI:
"Want to do" / "your wants"). Each is **"ready to go"**: it carries a real noun-verb `topic`
(same as an activity), so promoting it is one tap. Wants live on a user's profile; each is
**private or shared**. Friends can browse each other's **shared** wants; the system can surface
**overlap alerts** when two friends want the same thing. A want **promotes into a real
idea/activity** publishable through **any existing channel** (My Friends, a squad, or the
community bring-friends bridge) — reusing the current compose / `createIdea` path, not a
parallel one.

**Resolved direction (discussed; settle formally in `data-model` at pickup):** a want is its
**own `want` entity, NOT a state of `activity`**. The deciding reason isn't the one-shot case
(a one-shot want is *nearly* "an unpublished activity") — it's **ongoing aspirations**: an
`activity` is event-shaped and *confirms to a time + place*, whereas an ongoing want never
confirms and instead **spawns activities again and again**. An activity can't be a factory of
itself, so wants sit one layer above it. Promote = **spawn** a new activity (back-linked), not
flip a row's scope.

**In (anticipated):**

- A `want` entity: **required `topic`** (the noun-verb taxonomy — "ready to go"), optional
  title/place/notes; owner; **visibility {private | shared}**; **`kind: one_shot | ongoing`**
  (ongoing = a standing aspiration that can spawn repeatedly); created/updated.
- CRUD + a profile-hosted list view (your own: private + shared; a friend's: shared only).
- **Promote = spawn:** one tap opens the existing composer pre-filled from the want → posts
  through any channel the user can already publish to → creates an `activity` back-linked via
  `from_want_id`. A `one_shot` want archives after promoting; an `ongoing` one persists and can
  spawn again later.
- **Overlap detection:** when two *accepted friends* share wants that match (same `topic`, or
  fuzzy title/place match), surface a gentle alert/affordance ("You and Sam both want to try
  wakeboarding — plan it?") that deep-links into promote/compose.

**Out (initial):** ranking/prioritization; collaborative/shared-edit lists; non-friend
discovery; ML-grade matching (start with `topic`-equality + simple normalized-title match);
push delivery for overlap alerts (in-app first — rides on whatever realtime/notifications land).

**Not this plan — distinct from a "draft":** a *draft* (an idea you started composing but
haven't posted) is genuinely an *activity-not-yet-posted* and, if ever built, belongs as an
`activity` draft state/flag — downstream-adjacent to `idea`. A *want* is **upstream** of an
idea (a latent intent that may become one). Don't conflate them; this plan is wants.

## Implements (anticipated spec surface — written first when picked up)

- `specs/data-model.md` — the `want` entity (own table, **not** an `activity` state): required
  `topic`, `{private|shared}` visibility, `kind: one_shot | ongoing`, and the
  `activity.from_want_id` back-link. Promote spawns an activity (one→many for `ongoing`).
  Record *why* it's its own entity (the factory argument above).
- `specs/api/wants.md` (new) — list/create/update/delete, friend's-shared read, promote.
- `specs/api/profile.md` — profile gains a shared-wants read surface.
- `specs/screens/wants.md` (new) + profile screen entry; compose pre-fill from a want.
- `specs/behaviors/want-overlap.md` (new) — the matching rule + alert semantics + the privacy
  firewall (only *shared* wants are ever compared; private wants never leak).

## Approach (rough — refine at pickup)

- **Model (resolved direction):** own `want` entity with required `topic`, `{private|shared}`,
  `kind: one_shot | ongoing`. Activities reference it via `from_want_id`. Keeps `activity`'s
  invariants intact (every activity stays a topic-typed thing posted to an audience) and lets an
  `ongoing` want spawn many activities over time — which a `state` on `activity` could never
  model.
- Reuse **createIdea / the composer** for promote (any channel) — no new publish path. Promote
  *spawns* (creates a new activity); it never mutates/consumes the want in place, so `ongoing`
  wants keep producing.
- Overlap: start dumb and correct — exact `topic` match among accepted friends' shared wants,
  plus normalized-title equality; layer fuzziness later. Compute on read or on create/share
  (cheap at current scale); revisit if it needs realtime.
- Visibility reuses the **private-first** principle: shared ≠ public; only *accepted friends*
  see shared wants (same gate as the friends timeline). Private is owner-only, always. The
  visibility axis is **orthogonal to `scope`** — it's "can a friend browse my backlog," not
  "who do I broadcast to" — which is part of why a want isn't just an unpublished activity.

## Validation (sketch — finalize at pickup)

- [ ] backend: CRUD + visibility (a friend sees only my *shared* wants; never private); promote
      spawns a real idea via the existing path; overlap query returns only shared-vs-shared
      matches among accepted friends. `bun test` + type-check; CI.
- [ ] client: profile wants (own private+shared / friend's shared); add/edit/visibility toggle;
      promote → composer pre-filled → publishes to any channel; overlap affordance.
      `flutter analyze` + widget tests; CI.
- [ ] (machine free) MCP: add wants (one private, one shared) → friend sees only the shared one
      → overlap alert when both share a match → promote → publishes.

## Risks / unknowns

- **Model shape — direction resolved** (own `want` entity, not an `activity` state; see
  Scope/Approach). Still confirm in `data-model.md` before code, and decide the post-promote
  policy precisely (archive vs keep `one_shot`; spawn-history for `ongoing`).
- **Overlap privacy:** the matching must *never* compare or reveal private wants, and must
  respect the accepted-friend gate — a tempting place to leak. Spec the firewall explicitly.
- **Alert fatigue / channel:** overlap alerts need a delivery surface; likely waits on the
  realtime/notifications story. May split into "wants CRUD+promote" and "overlap alerts".
- Scope is large — likely **splits into 2–3 plans** at pickup (CRUD+promote; friend browsing;
  overlap alerts).

## Notes

(closeout)

## Follow-ups

(closeout)
