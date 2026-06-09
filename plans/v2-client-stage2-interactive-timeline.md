---
status: done
depends: [v2-client-stage1-auth-timeline]
specs:
  - specs/api/ideas-activities.md
  - specs/screens/friends-timeline.md
  - specs/behaviors/ideas-activities-lifecycle.md
  - specs/behaviors/response-system.md
issues: []
pr: 413
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

- [x] `GET /v1/topics` returns seeded topics; `bun test` + `flutter analyze`/`test` (4 widget
      tests) clean; CI `app` + `server` green on #413.
- [x] MCP end-to-end: logged in → composed "Go Paddleboarding" w/ two time options (FAB) →
      appeared on the timeline → opened detail → set response (1 in) → voted Sat 7am (1 vote) →
      confirmed as captain (state→confirmed, "Confirmed · Sat 7am"; DB verified). Screenshotted.
- [x] captain confirm control present (own idea); confirm controls disappear once confirmed.
- [~] non-captain-hides-confirm + suggest-option UI: confirm is gated on `captainId == me` in
      code but not driven from a second account this stage; suggest-option UI deferred (see
      Follow-ups).

## Risks / unknowns

- Provider invalidation after mutations (timeline + detail stay in sync without manual refetch).
- Detail screen needs a single-activity read; reuse timeline data vs a `GET /v1/ideas/:id`
  (no such endpoint yet — derive detail from the action responses, which return the activity).
- Keep the compose form minimal (all_friends only) to bound scope.

## Notes

Shipped as PR #413 (4 commits: GET /v1/topics + plan, client data layer, screens+routing,
tests+keys); CI green. The detail screen is seeded from the tapped tile's `Activity` (via
go_router `extra`) and each mutation returns the updated activity which is swapped into local
state + invalidates the timeline — so no `GET /v1/ideas/:id` was needed (none exists). Added
`captainId` to the Activity model to gate the captain-only confirm client-side. MCP-driven
flutter_driver needs unique keys for repeated controls — added `Key('vote_<id>')` /
`Key('confirm_<id>')` after the first run hit an ambiguous-finder error on two "Confirm" texts.

## Follow-ups

- **Deferred to plan:** suggest-option UI (gated by allow_suggestions); people-targeted
  audience picker in the composer; verify non-captain hides confirm + people-audience
  visibility by driving a second account; polished mock UI re-port; communities/squads/
  threads; SSE realtime; push.
- **Tracked as (skill feedback):** the flutter_driver "unique Key per repeated control"
  lesson joins the macOS gotchas already noted for the `mobile-flutter` skill.
