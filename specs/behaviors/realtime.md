# Behavior: Realtime (SSE + Postgres LISTEN/NOTIFY)

## Rule

Server→client live updates stream over **SSE** at `GET /v1/stream`, so the timelines and open
threads feel live without pull-to-refresh. Realtime is a **pure enhancement**: every screen renders
correctly from a plain authenticated fetch, and the app stays fully functional if the stream never
connects or drops mid-session (see
[realtime is an enhancement](../principles.md#realtime-is-an-enhancement-not-a-dependency)).

Events are a **nudge to refetch**, not the source of truth. A client receiving an event invalidates
the relevant cached query and refetches through the normal REST path; it does not trust the event
payload as authoritative state. This keeps the visibility/auth gates of the REST layer the single
source of truth and means a missed event only causes staleness-until-next-fetch, never incorrectness.

## Applies To

- `api/conventions.md` (Realtime section — the transport contract), `api/messages.md`
  (`message.created`), the friends/squad timeline screens and the thread drawer.
- `server/src/realtime/` (the LISTEN connection + subscriber fan-out), `GET /v1/stream`.

## The stream

- **`GET /v1/stream`** — authenticated, `Content-Type: text/event-stream`, held open. Because
  browser `EventSource` cannot set an `Authorization` header, the endpoint accepts the access token
  **either** as the `Authorization: Bearer …` header (native clients) **or** as a `?access_token=`
  query parameter (web). Same JWT, same validation.
- Emits a periodic comment/heartbeat (`: ping`) so proxies and the client keep the connection alive
  and can detect a dead link.
- The client reconnects with backoff; on (re)connect it should also refetch the screens it cares
  about, since events that occurred while disconnected were not buffered (best-effort, below).

## Event set

Each event is an SSE `event:` line + a small JSON `data:` payload (ids + just enough to route a
cache invalidation — never the full resource):

| event | when | payload |
|---|---|---|
| `activity.created` | a new idea/activity is posted | `{ id, scope, squad_id? }` |
| `message.created` | a squad message or thread reply is posted | `{ id, squad_id?, thread_target_type?, thread_target_id? }` |

The set is **extensible and additive** (future: `response.changed`, `vote.changed`,
`rsvp.changed`) — payloads only ever gain fields, like the REST contract. Clients ignore event
types they don't handle.

## Delivery guarantees

- **Best-effort, at-most-once, not durable.** Events are not queued for offline clients; there is no
  replay/`Last-Event-ID` backfill at launch. A client that was disconnected catches up via its next
  fetch (which the reconnect triggers). This is acceptable precisely because realtime is never
  load-bearing.

## Visibility (the privacy gate)

A subscriber receives an event **only if they could see the underlying resource via REST** — the
fan-out reuses the exact same gates (`ActivityService.canView`, squad membership, thread
`assertCanSeeTarget`), never a parallel check. An event the subscriber couldn't fetch is never
delivered. This is the load-bearing correctness rule: realtime must not become a side channel that
leaks existence or content past the REST visibility boundary.

## Infrastructure

- A **single** Postgres `LISTEN` connection per server process (separate from the query pool);
  domain writes `NOTIFY` a channel with the small JSON payload, and the process fans out to the
  matching open SSE subscribers. `min_instances=1` on Cloud Run keeps one `LISTEN` connection
  sufficient; multi-instance fan-out (e.g. Redis) is deferred until horizontal scaling is real.
- Long-lived SSE on Cloud Run must hold open without premature request timeout — validated as part
  of this work (flagged in `v2-backend-infra`).

## Principles

**Inherited:**

- [Realtime is an enhancement, not a dependency](../principles.md#realtime-is-an-enhancement-not-a-dependency)
  — the whole contract above is this principle made concrete: events nudge a refetch, correctness
  never depends on the stream.
- [Private-first](../principles.md#private-first-public-never-touches-the-friends-surface) — the
  per-subscriber visibility gate ensures the live channel exposes nothing the REST layer wouldn't.
