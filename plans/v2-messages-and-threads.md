---
status: done
depends: [v2-squads-context-selector]
specs:
  - specs/api/messages.md
  - specs/behaviors/thread-drawer.md
  - specs/screens/squads.md
  - specs/data-model.md
issues: []
pr: 420
---

# Plan: v2 messages + threads (text)

## Scope

Free-text messages: **squad top-level posts** (making the squad timeline the heterogeneous
activities+messages feed the spec describes) and **threads** (reply conversations) on
activities and on squad messages. Backend + client; styling deferred.

**In:** `message` table (text, squad XOR thread context); post squad message; heterogeneous
squad timeline (type-tagged activity|message); read/reply threads on activity + message
targets; real `thread_count`. Client: heterogeneous squad feed + a message composer + a
Discussion (thread) section on the activity detail.

**Out (later stages):** photo attachments + `POST /v1/uploads` (storage stage — body is
required for now); `community_event` thread targets (communities stage); SSE `message.created`
realtime (realtime stage — threads/feed render from fetch + pull-to-refresh); the slide-in
drawer animation + vote-bar restructure (visual polish).

## Implements

`specs/api/messages.md` (text paths), `specs/behaviors/thread-drawer.md` (conversation, sans
realtime/drawer-chrome), the message slice of `specs/data-model.md`, and the heterogeneous
feed of `specs/screens/squads.md`.

## Approach

- **Backend** (`server/`):
  - schema `message.ts`: `message` (id, sender→profile, body text nullable, squad_id nullable
    →squad, thread_target_type nullable enum {activity,community_event,message},
    thread_target_id nullable uuid, created_at) + migration. Exactly-one-context enforced in
    domain.
  - `MessageService`: postSquadMessage (member-gated, body required), postThreadReply +
    threadMessages (visibility per target: activity→`ActivityService.canView`,
    message→squad membership), thread counts (batched).
  - serializer `contracts/message.ts`; activity serializer gains real `thread_count`.
  - routes: `POST /v1/squads/:id/messages`; `GET`/`POST /v1/threads/:targetType/:targetId/messages`
    (targetType ∈ activity|message this stage); squad timeline route merges activities +
    messages → type-tagged, created_at-sorted, cursor-paginated.
  - tests.
- **Client** (`app/`):
  - `Message` model; `MessageRepository` (postSquadMessage, thread read/reply); squad timeline
    parses type-tagged items (activity|message).
  - squad timeline renders message tiles + a bottom **message composer** (squad context only).
  - activity detail gains a **Discussion** section: thread messages + a reply input
    (`threadProvider` family keyed by target).

## Validation

- [x] migration applies; `bun run type-check` + `bun test` (post squad message member-gated;
      heterogeneous squad timeline tags + ordering; activity thread reply audience-gated +
      thread_count; squad-message thread membership-gated; no free text on friends) — 3 tests,
      full suite 24/24; backend CI green (#419, merged).
- [x] client `flutter analyze` clean + 8 widget tests (ThreadView render/empty + updated
      timeline/detail/create-squad fakes); client CI on #420.
- [~] MCP visual walkthrough deferred (window-foreground conflict while the machine is in
      use); backend gating is unit-tested, the driver loop proven in prior stages.

## Risks / unknowns

- Heterogeneous cursor pagination across two tables — fetch limit+1 from each, merge/sort in
  memory, derive the cursor from the merged page.
- Thread visibility must reuse the existing predicates (activity canView / squad membership),
  not re-derive them.
- Squad-timeline response shape gains `type` on items — additive, but the client must branch.

## Notes

Two PRs: **#419** (backend — message schema/migration 0003, MessageService with per-target
visibility reused from ActivityService.canView / squad membership, heterogeneous squad
timeline, real thread_count, 3 tests) merged; **#420** (client — Message/FeedItem models,
MessageRepository, squadFeed, message tiles + squad composer, reusable ThreadView embedded in
activity detail + a ThreadScreen). Heterogeneous feed merges two tables in memory (fetch
limit+1 each, sort, derive cursor). Squad-timeline items gained an additive `type` field; the
client branches on it.

## Follow-ups

- **Deferred to plan:** photo attachments + `POST /v1/uploads` (storage stage — `attachments`
  is `[]` for now); SSE `message.created` realtime (realtime stage — feed/threads render from
  fetch + pull-to-refresh); `community_event` thread targets (communities stage); the slide-in
  drawer chrome + persistent vote-bar restructure (visual polish).
- **Deferred (visual QA):** MCP walkthrough of post-message + activity-thread reply when the
  machine is free.
