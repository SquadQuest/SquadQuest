---
status: done
depends: [v2-backend-stage1-auth]
specs:
  - specs/api/ideas-activities.md
  - specs/api/timeline.md
  - specs/data-model.md
  - specs/behaviors/ideas-activities-lifecycle.md
  - specs/behaviors/response-system.md
issues: []
pr: 409
---

# Plan: v2 backend Stage 2 — ideas/activities + friends timeline

## Scope

The core social loop on top of Stage 1: the idea↔activity lifecycle and the My Friends
timeline. Backend only. Friends-scoped only (squad scope, community link / event_ref /
bring-friends, threads/messages, and SSE realtime are deferred to their own stages).

Audience: both `all_friends` and `people`-targeted (adds `activity_audience` + per-viewer
visibility filtering).

## Implements

`specs/api/ideas-activities.md`, friends section of `specs/api/timeline.md`, activity slice
of `specs/data-model.md`, `behaviors/{ideas-activities-lifecycle,response-system}.md`.

## Approach

- **Schema** (`src/db/schema/activity.ts` + migration): `activity` (captain, activity_type→
  topic, state idea|confirmed, scope friends|squad default friends, audience_kind
  all_friends|people, allow_suggestions, confirmed_time/location_option FKs, created/confirmed
  timestamps; squad_id + community_event_id nullable/unused), `activity_option` (kind
  time|location, label, created_by), `option_vote` (option,profile), `response`
  (activity,profile,value), `activity_audience` (activity,profile).
- **Domain** (`src/domain/activity/`): createIdea (friends-only, transactional, options +
  people-audience rows), set/clear response, add option (allow_suggestions + visibility),
  toggle vote, confirm (captain-only). **Visibility predicate** reused by reads + write authz:
  viewer sees an activity iff captain ∈ {viewer} ∪ accepted-friends(viewer) AND
  (audience_kind=all_friends OR viewer ∈ activity_audience).
- **Serializer** (`src/contracts/activity.ts`): batched wire-shape assembler (options w/ vote
  counts + you_voted, your_response, counts, confirmed_time/location labels, audience.summary;
  thread_count:0, event_ref:null, squad_id:null this stage).
- **Routes** (`src/routes/v1/{ideas,timeline}.ts`, authed): POST /v1/ideas; PUT/DELETE
  /v1/ideas/:id/response; POST /v1/ideas/:id/options; PUT /v1/ideas/:id/votes; POST
  /v1/ideas/:id/confirm; GET /v1/timeline/friends (cursor created_at,id).

## Validation

- [x] migration applies; `bun run type-check` clean.
- [x] create idea (all_friends + people) → appears on `GET /v1/timeline/friends` for an
      in-audience friend; hidden from a non-friend and an out-of-audience user.
- [x] response set/clear updates your_response + counts; option suggest gated by
      allow_suggestions; vote toggle updates votes/you_voted.
- [x] confirm as captain → state=confirmed + confirmed_time/location; non-captain → 403
      not_captain.
- [x] cursor pagination walks history; `bun test` + `pr-test` server job green.

## Risks / unknowns

- Visibility query (friend graph × audience) correctness + avoiding N+1 in the page serializer.
- Stable cursor over (created_at, id).
- `activity_option` single-table-with-kind is an impl choice vs the spec's two named concepts.

## Notes

(closeout)

## Follow-ups

(closeout)
