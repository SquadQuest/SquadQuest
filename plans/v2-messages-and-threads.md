---
status: in-progress
depends: [v2-squads-context-selector]
specs:
  - specs/api/messages.md
  - specs/behaviors/thread-drawer.md
  - specs/screens/squads.md
  - specs/data-model.md
issues: []
pr:
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

- [ ] migration applies; `bun run type-check` + `bun test` (post squad message member-gated;
      heterogeneous squad timeline tags + ordering; activity thread reply visible to audience,
      non-member/non-audience 403/404; thread_count) green; CI green.
- [ ] client `flutter analyze` + widget tests green; CI green.
- [ ] (when machine free) MCP: post a squad message → appears in the squad feed; reply on an
      activity → shows in its Discussion + thread_count increments; messages never on My Friends.

## Risks / unknowns

- Heterogeneous cursor pagination across two tables — fetch limit+1 from each, merge/sort in
  memory, derive the cursor from the merged page.
- Thread visibility must reuse the existing predicates (activity canView / squad membership),
  not re-derive them.
- Squad-timeline response shape gains `type` on items — additive, but the client must branch.

## Notes

(closeout)

## Follow-ups

(closeout)
