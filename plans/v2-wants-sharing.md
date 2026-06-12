---
status: planned
depends: [v2-wants-core]
specs: []
issues: []
pr:
---

# Plan: v2 wants — sharing (friends browse each other's shared wants)

> **Backlog stub.** The second slice of wants (split from the original `v2-wants`). `v2-wants-core`
> ships the `want` entity with a `visibility {private|shared}` column but enforces **owner-only
> reads**. This plan opens the **friend-read surface**: an accepted friend can browse another's
> *shared* wants (never private).

## Scope

**In (anticipated):**

- A read API for a friend's **shared** wants (e.g. `GET /v1/profiles/:id/wants` → shared only),
  gated to **accepted friends** (same gate as the friends timeline).
- Profile-screen surface: viewing a friend's profile shows their shared wants; your own list keeps
  showing private + shared.
- Reuse the want serializer; the only new logic is the visibility + friendship gate.

**Out:** overlap detection/alerts (`v2-wants-overlap`); editing others' wants; non-friend discovery.

## Implements (anticipated — specs first at pickup)

- `specs/api/wants.md` — friend's-shared read endpoint + the accepted-friend gate.
- `specs/api/profile.md` — the shared-wants read surface on a viewed profile.
- `specs/screens/wants.md` / profile screen — friend's-wants view.
- `specs/behaviors/` or `principles.md` reference — private-first: shared ≠ public; only accepted
  friends ever see shared wants; private never leaves the owner.

## Validation (sketch)

- [ ] a friend sees only my *shared* wants, never private; a non-friend sees none; I still see my
      own private + shared. Tests. CI.
- [ ] client: a friend's profile lists their shared wants. `flutter analyze` + widget tests.

## Notes

(closeout)

## Follow-ups

(closeout)
