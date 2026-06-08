# API: Conventions

The contract between the v2 Flutter client and the Fastify/Bun backend. Every endpoint spec
inherits these conventions. The client binds **only** to this contract, never the schema
(see [principles](../principles.md#the-client-binds-to-the-versioned-api-never-the-schema)).

## Base + transport

- Base URL: `https://api.squadquest.app`
- JSON over HTTPS. UTF-8. Request/response bodies are JSON unless noted (uploads use signed
  URLs — see Storage).

## Versioning

Three tiers, each with a distinct job:

| Lever | Job | Frequency |
|---|---|---|
| **URL major** `/v1/…` | the coarse contract boundary | almost never bumped |
| **path within `/v1`** | the fine-grained contract unit — evolve by add/supersede | the everyday lever |
| **client-build header** | telemetry + upgrade floor (+ optional per-build response shaping) | every request |

### URL major version

All endpoints live under `/v1/…`. A new major (`/v2`) is reserved for a **wholesale
redesign** so cross-cutting that maintaining old-shape adapters across many endpoints costs
more than a clean parallel surface. Expect years between majors, if ever.

### Additive / tolerant-reader (the everyday rule)

Within a major version:

- **Never remove, retype, or repurpose a field a released client reads.** New meaning ⇒
  new field.
- **New fields are additive and optional**; clients ignore unknown fields.
- **New endpoints are free.**
- Break a single endpoint by **superseding**: ship a new path/field alongside the old,
  deprecate the old, delete it once the upgrade floor passes the last build that used it.
- The DB schema churns freely behind the API; per-build/per-shape **serializers** at the
  route edge map current schema → stable wire shapes. Business logic speaks one current
  domain model; version logic lives only in edge adapters (`server/src/contracts/`).

### Client build header (required on every request)

```
X-SquadQuest-Client: <platform>/<version>+<build>      e.g. ios/1.4.2+312
```

Used for: (1) telemetry on the live build distribution; (2) the upgrade floor; (3) optional
per-build **response** shaping when a read shape must change (fork the serializer, not the
handler). The client never asks for "version N of X" — it calls the URLs baked into its
build; the header is how the *server* learns who's calling.

### Upgrade floor

The server holds a `min_supported_build` per platform. A request below it returns
**`426 Upgrade Required`** with the standard error envelope and an `upgrade` block the
client renders as a blocking "please update" screen. The floor is both the humane handling
of an unavoidable break *and* the garbage-collector that lets deprecated/superseded paths
be deleted (once no supported build calls them).

### Worked example — breaking `/v1/ideas`

Two cases, two mechanics:

- **Response-shape break** (an idea is *returned* differently): usually **no new endpoint**.
  The serializer forks on client build — old builds get the old shape derived from the new
  schema, new builds get the new shape. Same path.
- **Request-shape break** (old clients can't *send* the new body): **supersede the path**.
  The old `POST /v1/ideas` stays (adapts old body → current domain model), the new shape
  ships at a successor path under the same `/v1` (e.g. `POST /v1/idea-drafts`), the old is
  marked deprecated. Lifecycle: ship new alongside old → telemetry → raise
  `min_supported_build` past the last build using the old path → delete the old route +
  adapter + any now-dead columns.

Behind both: an expand/contract migration — add new columns/tables, backfill, derive the
old wire fields from the new schema in the serializer.

## Auth

- Bearer JWT: `Authorization: Bearer <access_token>`.
- Access tokens are short-lived; refresh via `api/auth.md`. Issued by our backend after
  phone-OTP (we own auth — no third-party identity in the contract).
- Authorization is enforced server-side per endpoint (no RLS, no client-direct).
- Unauthenticated/expired → `401`; authenticated-but-forbidden → `403`.

## Error envelope

Non-2xx responses share one shape:

```jsonc
{
  "error": {
    "code": "string",          // stable, machine-readable (e.g. "not_friends", "otp_invalid")
    "message": "string",       // human-readable, not for control flow
    "details": { }             // optional, code-specific
  },
  "upgrade": {                 // present only on 426
    "min_build": 320,
    "store_url": "https://…"
  }
}
```

Clients branch on `error.code`, never on `message`. Codes are additive (new codes may
appear; clients treat unknown codes as a generic failure).

## Pagination

List endpoints are **cursor-based** (the timeline scrolls up through history, group-text
style — see [group text, not feed](../principles.md#group-text-not-social-feed)):

```
GET /v1/<list>?limit=50&before=<cursor>
→ { "items": [...], "next_cursor": "…" | null }
```

`before` walks backward in time (older). `next_cursor` null means no older items.

## Realtime (enhancement, not dependency)

- Server→client updates stream over **SSE**: `GET /v1/stream` (authenticated), emitting
  typed events (`activity.created`, `response.changed`, `message.created`, `vote.changed`,
  …) scoped to what the user may see.
- Writes are ordinary POSTs; the resulting change fans out over SSE via Postgres
  `LISTEN/NOTIFY`.
- Event payloads follow the same additive rule (only gain fields).
- **Every screen must render correctly from a plain fetch**; SSE only makes it feel live.
  See [realtime is an enhancement](../principles.md#realtime-is-an-enhancement-not-a-dependency).

## Storage (photos)

- Uploads use **signed URLs**: client requests an upload target from the API, PUTs the
  bytes directly to the object store, then references the returned key. The API never
  proxies image bytes.
- Reads are signed (or public-with-unguessable-key) URLs returned in serialized resources.

## Principles

**Inherited:**

- [The client binds to the versioned API, never the schema](../principles.md#the-client-binds-to-the-versioned-api-never-the-schema)
  — this whole document is that principle operationalized.
- [Realtime is an enhancement, not a dependency](../principles.md#realtime-is-an-enhancement-not-a-dependency)
  — the SSE section; fetches are authoritative.
