---
status: in-progress
depends: [v2-client-stage1-auth-timeline]
specs:
  - specs/api/ideas-activities.md
  - specs/screens/friends-timeline.md
  - specs/behaviors/ideas-activities-lifecycle.md
  - specs/behaviors/response-system.md
issues: []
pr:
---

# Plan: v2 client Stage 2 — interactive timeline (compose + respond/vote/confirm)

## Scope

Make the My Friends timeline interactive by wiring the rest of the Stage-2 API into the
client: create an idea, respond (in/interested/next_time), vote on options, suggest an option,
and (as captain) confirm. Adds the one missing backend bit: `GET /v1/topics`.

Out: people-targeted audience picker (all_friends only this stage); communities/squads/threads;
polished mock UI re-port; SSE realtime; push.

## Implements

Client side of `specs/api/ideas-activities.md` (POST /ideas, PUT/DELETE response, POST options,
PUT votes, POST confirm) + `behaviors/{ideas-activities-lifecycle,response-system}.md`; new
`GET /v1/topics` (backend).

## Approach

- **Backend**: `GET /v1/topics` (authed) → list topics (id, noun, verb, label) via a small
  contract serializer; + a route test.
- **Client**:
  - models: `Topic`.
  - repositories: `TopicRepository` (list) + `ActivityRepository` (createIdea, setResponse,
    clearResponse, vote, addOption, confirm) — abstract + Api impls + fakes.
  - providers: `topicsProvider`; `activityRepositoryProvider`; mutations invalidate
    `friendsTimelineProvider` (and the detail provider).
  - screens: **compose idea** (topic pick, allow_suggestions, time/location options →
    POST /ideas) reached via a timeline FAB; **activity detail** (`/activity/:id`) showing
    options with vote toggles, response selector, suggest-option (if allowed), confirm
    (captain only) — reached by tapping a tile.
  - router: add `/ideas/new` and `/activity/:id`.

## Validation

- [ ] `GET /v1/topics` returns seeded topics; `bun test` + `flutter analyze`/`test` clean; CI green.
- [ ] MCP end-to-end: log in → compose an idea (FAB) → it appears on the timeline → open detail
      → set response (counts update) → vote an option (count/you_voted update) → confirm as
      captain (state→confirmed, time/location shown). Screenshot each.
- [ ] non-captain sees no confirm control; suggest-option hidden when allow_suggestions=false.

## Risks / unknowns

- Provider invalidation after mutations (timeline + detail stay in sync without manual refetch).
- Detail screen needs a single-activity read; reuse timeline data vs a `GET /v1/ideas/:id`
  (no such endpoint yet — derive detail from the action responses, which return the activity).
- Keep the compose form minimal (all_friends only) to bound scope.

## Notes

(closeout)

## Follow-ups

(closeout)
