---
status: done
depends: []
specs:
  - specs/api/messages.md
  - specs/api/communities.md
  - specs/api/conventions.md
  - specs/screens/communities.md
issues: []
pr: 443
---

# Plan: v2 API drift cleanup

> **Backlog stub** (`status: planned`). A spec-drift audit (June 2026) found several spec↔code
> gaps where the spec over- or under-claims vs. the running backend. None are urgent, but they'd
> mislead a client written to spec. Grouped here so they have a living home instead of rotting.
> Each item names the resolution direction; settle in the relevant spec at pickup.

## Scope

Close the gaps the auditor flagged. Most are small; the community-event thread one is real
functionality.

**In:**

1. **Community-event threads unreachable (High).** The `thread_target_type` enum has
   `community_event`, `CommunityService` already computes `thread_count` for it, and
   `specs/api/messages.md` lists it as a valid target — but `parseTargetType` in
   `routes/v1/messages.ts` rejects it (`invalid_target` 400), so `GET/POST
   /v1/threads/community_event/:id/messages` is a dead route. **Resolution: implement** — add
   `community_event` to `ThreadTargetType`, add its visibility check in `assertCanSeeTarget`
   (anyone who can see the event), and accept it in `parseTargetType`. This makes the
   already-serialized `thread_count` actionable.

2. **Communities list pagination (Medium).** `specs/api/communities.md` says `GET /v1/communities`
   is "cursor-paginated", but the route returns a flat `{ items }` with no `limit`/`before`/
   `next_cursor`. **Resolution: update the spec** to "returns all (no cursor) for now" — defer real
   pagination until community count warrants it. (Or implement cursors; spec-update is the
   cheaper honest fix.)

3. **Client-build header not enforced (Low).** `conventions.md` says `X-SquadQuest-Client` is
   "required on every request"; `client-version.ts` intentionally allows absent headers (a
   commented Stage-1 simplification). **Resolution: update the spec** to document the current
   relaxed behavior + that tightening is a later step (or tighten + keep the spec).

4. **`/communities/:id/timeline` alias (Low).** `screens/communities.md` references
   `GET /v1/communities/:id/timeline` (or `/events`); only `/events` exists. **Resolution:** strike
   `/timeline` from the screen spec (simplest) or add the alias.

**Out:** the `errors.forbidden(code,message)` helper signature oddity (internal cleanup, wire
behavior is already correct — fix opportunistically, not worth gating); OTP `expires_in` value
docs (informational only).

## Implements

Touches `specs/api/messages.md` (community_event threads — already specified, just wire code),
`specs/api/communities.md` (pagination wording), `specs/api/conventions.md` (header wording),
`specs/screens/communities.md` (timeline alias). Item 1 is code-to-match-spec; 2–4 are
spec-to-match-code.

## Validation

- [x] community_event threads: `GET`/`POST /v1/threads/community_event/:id/messages` work, gated
      to who can see the event; `thread_count` on event cards becomes reachable. Tests.
- [x] specs updated for pagination wording, client-header wording, timeline alias — no remaining
      drift on these (re-run `/audit-spec-drift`).
- [x] `bun test` (51 pass) + `type-check` (clean); CI.

## Risks / unknowns

- community_event visibility check must reuse the event's existing visibility (follower/anyone-
  who-can-see), not invent a new gate — mirror how activity/message targets are checked.
- Don't accidentally implement pagination half-way; pick spec-update OR full cursors, not a stub.

## Notes

All four audit findings resolved in one PR (#443), two commits:

- **Item 1 (code-to-match-spec):** `community_event` is now a live thread target. The visibility
  gate reuses the open-community read model — any authenticated viewer who can see the event
  (i.e. it exists) can read/reply; no follower gate, mirroring `events`/`discover` which never
  gate on membership. Implemented by querying `communityEvent` directly in
  `MessageService.assertCanSeeTarget` rather than coupling to `CommunityService`. New test in
  `messages.test.ts` covers reply→read→`thread_count` reachable→bad-target 404.
- **Items 2–4 (spec-to-match-code):** chose the cheaper honest fix (spec update) for all three,
  as the plan anticipated. Pagination → "flat `{items}`, no cursor yet"; `/timeline` alias struck
  from both `communities.md` and `screens/communities.md`; client-header reworded from "required"
  to "sent by every client, absence tolerated (Stage-1), tightening deferred."

## Follow-ups

- **Deferred (tracked in spec prose, no plan needed):** real community-list pagination — revisit
  when community count warrants it (noted in `communities.md`).
- **Deferred (tracked in `conventions.md` + `client-version.ts` comment):** hard-require the
  client-build header (reject absent/unparseable with `400`) once every shipped build is known to
  send it. Latent companion footgun from the prior session still stands: `MIN_SUPPORTED_BUILD` is
  set process-wide by `auth.test.ts` and leaks across the shared bun-test process — proper fix is
  per-suite env reset; not addressed here.
- **None** for the `errors.forbidden` signature nit and OTP `expires_in` docs — explicitly out of
  scope, not worth tracking.
