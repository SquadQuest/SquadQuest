---
status: planned
depends: [v2-backend-infra]
specs: []
issues: []
pr:
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

- [ ] server: NOTIFY on key writes; SSE delivers only visible events; suite + type-check.
- [ ] client: a second session sees a new message/activity appear without manual refresh;
      stream drop → app still works via pull-to-refresh.
- [ ] (prod) SSE holds open on Cloud Run without premature timeout.

## Risks / unknowns

- **SSE on Cloud Run**: request timeouts + scaling vs long-lived streams — the open question
  from `v2-backend-infra`. Validate before building much on it.
- **Visibility filtering** per subscriber must reuse the same gates as the REST reads, or
  realtime becomes a privacy leak. Spec the event→audience mapping explicitly.
- Keep it an enhancement: never let a screen *require* the stream to function.

## Notes

(closeout)

## Follow-ups

(closeout)
