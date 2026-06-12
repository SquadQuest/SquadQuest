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

# Plan: v2 wants — core (shared pre-activity → promote to idea)

> Core slice of the wants feature. The founding use case: run into a friend, "I keep my
> paddleboard in my car, you keep your kayak — let's hit FDR lake soon!" → friend each other,
> create a want, invite them, and when it's mutual, one tap promotes it to a real dated plan.
> Specs first (this plan's first PR), then backend, then client.

## Scope

A **loose, shared pre-activity**: an intent + the friends you'd do it with, captured before there's
a time or place. The entity is a **`want`** (UI: "Want to do"), carrying a real noun-verb `topic`
(same taxonomy as an activity) so it's "ready to go" — promoting is one tap.

**Model (resolved):** a want is its **own entity, NOT a state of `activity`** — because (1) an
`ongoing` want never confirms and **spawns activities repeatedly** (an activity can't be a factory
of itself), and (2) a want's *invitees* ("people I'd do this with someday") are distinct from an
activity's *audience* ("who I'm posting this dated plan to now"). Promote = **spawn** a new activity
(`from_want` back-link), never flip a row.

**Privacy is derived, not declared:** no visibility flag — a want with no invitees is private;
inviting an accepted friend shares it with exactly them. Invites are the *entire* sharing
mechanism (there is no "browse a friend's wants"). Invite responses reuse the activity response
vocabulary (`in | interested | next_time`, no decline; ignoring is a silent dismiss never shown to
the owner — see `behaviors/response-system.md`).

**In:**

- `want` entity: required `topic`, optional `title`/`location`/`notes`, `owner`,
  `kind: one_shot | ongoing`, `archived_at`, created/updated.
- `want_invite` (`want`, `profile`, `response | null`) — invite accepted friends; invitee responds.
- CRUD for your own wants; **invite/uninvite** friends; **respond** to invites; a **hide-from-my-
  invited-list** dismiss (never surfaced to the owner).
- Two list surfaces: **Yours** (with invitee responses) and **Invited** (with your response).
- **Promote = spawn (owner):** one tap opens the existing composer **pre-filled** — topic locked;
  **audience pre-filled to the want's invitees (editable)**; title/location seed option hints →
  posts through any channel → creates an `activity` with `from_want` set. `one_shot` archives;
  `ongoing` persists.

**Out (this slice → later/cancelled):** browse-a-friend's-list sharing (**cancelled** — invites ARE
sharing); mutual-wants *signal* across un-connected wants (`v2-wants-overlap`, someday); ranking;
collaborative shared-edit lists.

## Implements (specs written first, this plan's first PR)

- `specs/data-model.md` — the `want` entity (own table, not an `activity` state): required `topic`,
  `{private|shared}`, `kind: one_shot | ongoing`, `archived_at`; plus `activity.from_want_id`
  back-link. Record *why* it's its own entity (the factory argument).
- `specs/api/wants.md` (new) — list/create/update/delete own wants + promote.
- `specs/screens/wants.md` (new) + a profile-screen entry point; compose pre-fill from a want.
- `specs/api/profile.md` — note the wants entry point.

## Approach

- **Backend:** `want` + `want_invite` Drizzle tables + migration; `WantService` (CRUD scoped to
  owner; invite/uninvite gated to accepted friends; invitee `respond`/clear; owner sees a want +
  its invites, an invitee sees a want they're invited to; `promote` calls the existing
  `ActivityService.createIdea` — defaulting audience to the want's invitees when none given — then
  sets `from_want`, archiving the want when `kind = one_shot`). Routes under `/v1/wants`.
  `from_want` is a nullable uuid on `activity` (no behavior change to existing creates).
- **Promote reuses createIdea / the composer** — no parallel publish path. Promote *spawns*; it
  never mutates the want except setting `archived_at` for `one_shot`.
- **Client:** `Want` + invite models, repo, providers; a wants screen with **Yours** + **Invited**
  groupings; add/edit with kind + friend-invite picker; respond controls on invited wants (reuse the
  response-row pattern); profile entry point; promote routes into `ComposeIdeaScreen` pre-filled
  (extend it to accept an optional want seed — topic + invitee audience + option hints).
- **Privacy is derived:** no visibility flag — owner-only until an invite exists; an invitee can
  read + respond but not edit. Friend gate on invite = accepted-friends only (same as the timeline).

## Validation

- [ ] backend: CRUD scoped to owner; invite only accepted friends; an invitee reads the want + can
      respond (no decline) + hide-from-their-list (never shown to owner); promote spawns a real idea
      via the existing path with `from_want` set + audience defaulted to invitees; `one_shot`
      archives, `ongoing` persists. `bun test` + type-check; CI.
- [ ] client: Yours + Invited lists; add/edit + invite friends + kind; respond to an invite; promote
      → composer pre-filled (topic + invitee audience) → publishes to any channel. `flutter analyze`
      + widget tests; CI.
- [ ] (on-device, post-merge) create a want inviting a friend; the friend sees it + responds; owner
      sees the response; promote → posts to those invitees; one_shot archives.

## Risks / unknowns

- Post-promote policy decided: `one_shot` → `archived_at` set; `ongoing` → stays. List filters
  archived by default.
- Composer pre-fill: `ComposeIdeaScreen` seeds from `broughtEvent` only today — adding a want seed
  (topic + people audience + option hints) must stay additive and not disturb the bring-friends path.
- **Invite privacy:** an invitee sees the want (topic/title/notes/owner + co-invitees + responses);
  confirm that's intended (it is — invitees are collaborators on a shared intent). A non-invited
  friend sees nothing. No "browse my wants" surface exists, so there's no accidental-leak path
  beyond the invite itself.
- Scope grew with invites — still one shippable slice, but the largest of the session. If the client
  half balloons, the invite-response UI could split to a fast-follow (backend stays whole).

## Notes

(closeout)

## Follow-ups

(closeout)
