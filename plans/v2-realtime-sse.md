---
status: done
depends: [v2-backend-infra]
specs:
  - specs/behaviors/realtime.md
  - specs/api/conventions.md
issues: []
pr: 465
---

# Plan: v2 realtime (SSE + Postgres LISTEN/NOTIFY)

> **Backlog stub** (`status: planned`). Realtime has been named as the intended path since the
> architecture spec; many done plans note "SSE is an enhancement, never load-bearing." This is
> its first living home. Specs-first at pickup.

## Scope

Push live updates to clients instead of pull-to-refresh, as an **enhancement layer** — the app
must stay fully functional if the stream drops (architecture principle). First surfaces: the
friends/squad timelines and open threads (new messages/replies appear without manual refresh).

**In (anticipated):**

- Server: an SSE endpoint (e.g. `GET /v1/stream`) that fans out events sourced from Postgres
  `LISTEN/NOTIFY`; emit on the writes that matter (new activity, new message/reply, RSVP/face-pile
  change). Auth'd; scoped so a client only receives events it may see (reuse `canView`/membership).
- Client: an SSE consumer that invalidates the relevant Riverpod providers on an event (or merges
  the payload), with reconnect/backoff; pull-to-refresh stays as the fallback.

**Out:** typing indicators / presence; a generic pub/sub for all resources (start with the few
high-value surfaces); Redis fan-out (only if/when multi-instance — `min_instances=1` today keeps
a single `LISTEN` connection simple, noted in `v2-backend-infra`).

## Implements

New `specs/behaviors/realtime.md` (the event set, delivery guarantees = best-effort, the
"never load-bearing" rule) + touches to the screen specs that consume it. Written first at pickup.

## Approach (rough — refine at pickup)

- One Postgres `LISTEN` connection on the server; domain writes `NOTIFY` a channel with a small
  JSON payload (kind + ids). The SSE handler filters per-subscriber by visibility and streams.
- Cloud Run: `min_instances=1` + a generous request timeout already set; validate long-lived SSE
  there (the `v2-backend-infra` plan flagged this as the thing to confirm for real).
- Client: a thin SSE client feeding `ref.invalidate(...)`; treat the stream as a *nudge to
  refetch*, not the source of truth, so a dropped stream just means staler-until-refresh.

## Validation

- [x] server: NOTIFY on the key writes (activity.created on POST /ideas; message.created on squad
      message + thread reply); SSE fan-out delivers only to subscribers who pass the same visibility
      gate as REST. `realtime.test.ts`: gated delivery + unsubscribe + malformed-payload resilience.
      `bun test` 66 pass; type-check clean.
- [x] client: `RealtimeService` parses the SSE stream → invalidates the matching providers
      (timelines/thread); connection self-gates on auth + reconnects with backoff; pull-to-refresh
      remains the fallback. Parser unit-tested (split frames, heartbeats, junk). `flutter analyze`
      clean; suite 34 pass.
- [x] **(prod)** confirmed: SSE held cleanly with 25s heartbeats; the 300s Cloud Run request
      timeout was the only limit (force-close at 302s). Raised `timeout` → 3600s (`tf/cloudrun.tf`,
      PR #466) and re-verified a 375s hold with no error. The client reconnect+refetch covers the
      hourly close. (Cross-session "see it live" left for on-device — the fan-out + invalidation are
      unit-tested.)

## Risks / unknowns

- **SSE on Cloud Run**: request timeouts + scaling vs long-lived streams — the open question
  from `v2-backend-infra`. Validate before building much on it.
- **Visibility filtering** per subscriber must reuse the same gates as the REST reads, or
  realtime becomes a privacy leak. Spec the event→audience mapping explicitly.
- Keep it an enhancement: never let a screen *require* the stream to function.

## Notes

PR #465. Spec written first (`behaviors/realtime.md` + a tightened conventions.md realtime section).

Key implementation choices:

- **Events are id-only nudges to refetch**, never authoritative state — so the REST visibility gates
  stay the single source of truth and a missed event only causes staleness, never incorrectness.
- **Visibility reuse, not reimplementation:** the fan-out's per-subscriber `canSee` calls
  `ActivityService.canView` / `SquadService.isMember` / `MessageService.canSeeThread` (a new boolean
  wrapper over the existing thread gate) — the load-bearing privacy rule.
- **Dual auth on `/v1/stream`:** Bearer header (native) OR `?access_token=` (browser EventSource
  can't set headers); a `verifyAccessToken` helper added to the auth plugin.
- **Client uses streamed dio, not EventSource** — works uniformly on mobile + web and lets native
  clients use the header path.
- **publish() never blocks the write** — NOTIFY failures are logged and swallowed (enhancement).

## Follow-ups

- **(prod validation, above):** confirm long-lived SSE survives Cloud Run's request timeout — the
  open question carried from `v2-backend-infra`. `min_instances=1` keeps a single LISTEN connection
  sufficient; revisit fan-out (Redis) only if/when multi-instance.
- **Deferred (out of scope):** more event types (`response.changed`, `vote.changed`, `rsvp.changed`)
  — additive when wanted; presence/typing; offline replay (`Last-Event-ID`).
