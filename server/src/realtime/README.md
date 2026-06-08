# realtime/

Server→client live updates: SSE (`GET /v1/stream`) fanned out via Postgres
`LISTEN/NOTIFY`. An enhancement, never load-bearing — every screen renders from a
plain fetch. See `specs/api/conventions.md` (Realtime) and
`specs/principles.md#realtime-is-an-enhancement-not-a-dependency`.
