---
status: done
depends: [v2-friends-and-onboarding]
specs:
  - specs/principles.md
  - specs/screens/ignored.md
  - specs/api/friends.md
  - specs/behaviors/friend-connections.md
issues: []
pr: 461
---

# Plan: v2 ignore + recovery (silent dismissal, app-wide)

> Implements the [dismissal is silent and reversible](../specs/principles.md#dismissal-is-silent-and-reversible)
> principle for **friend requests** + the shared **Ignored** recovery screen. (Want-invite ignore
> ships with `v2-wants-core`, referencing the same principle; idea/activity responses already
> embody it and need no change.) Specs landed in the principle PR; this is the code.

## Scope

**In:**

- **Backend — friends:** replace the `declined` status with **silent ignore**. `friendship` gains
  `ignored_at` (keep `status ∈ {requested, accepted}`; **drop `declined`**). `respond(accept:false)`
  is removed; add `ignore` (sets `ignored_at`, edge stays `requested`) + `unignore` (clears it).
  `GET /v1/friends/requests` `incoming` excludes ignored; **outgoing is unchanged regardless** (the
  sender never sees a state change). Routes: `POST /v1/friends/requests/:id/ignore` + `/unignore`;
  `PUT …` accepts only `{accept:true}`.
- **Backend — recovery:** `GET /v1/ignored` aggregating ignored incoming items (friend requests
  now; want invites once `v2-wants-core` lands — the aggregator should be extensible).
- **Client:** ignore action on incoming friend requests (replaces decline); a new **Ignored** screen
  (`/ignored`) from the profile entry; un-ignore restores to incoming. Tests both layers.
- **Migration:** existing `declined` rows → set `ignored_at` (treat a past decline as an ignore) and
  move to `requested`, OR drop them (decline wasn't a block; re-requestable). Decide at pickup;
  lean toward converting so nothing is lost.

**Out:** blocking (still a separate future plan); ignoring item types beyond friend requests +
want invites; push/notification suppression nuance.

## Implements

`specs/principles.md` (dismissal is silent and reversible), `specs/screens/ignored.md` (new),
`specs/api/friends.md` (ignore/unignore + `/v1/ignored`), `specs/behaviors/friend-connections.md`
(no `declined`), `specs/data-model.md` (`friendship.ignored_at`, no `declined`).

## Approach

- This is **code-catching-up-to-spec**: the friends backend currently ships `declined` (PR #426);
  the spec now forbids it. Migrate the column, swap the service method, update the route + client.
- `GET /v1/ignored` is a small aggregator; design its response so want invites (and later types)
  slot in by `type` without a new endpoint per type.
- The Ignored screen is a thin list + un-ignore action; reuse the friend-request row widget.

## Validation

- [x] backend: ignoring a request leaves the sender's outgoing view unchanged (still pending);
      ignored requests leave the requestee's incoming + appear in `/v1/ignored`; un-ignore restores;
      no `declined` status remains (enum is `requested|accepted`). Migration converts existing
      `declined` rows → `requested` + ignored_at. `bun test` 62 pass; type-check clean.
- [x] client: ignore from incoming; Ignored screen lists + un-ignores; `{accept:false}` rejected.
      `flutter analyze` clean; suite 32 pass (+3).
- [x] no `declined` left in server/client code (only an explanatory comment). Test DB verified:
      enum `{requested,accepted}`, `friendship.ignored_at` present, migration 0007 applied.

## Risks / unknowns

- **Migration of existing `declined` rows** — converting vs dropping; pick at pickup (lean convert).
- The `respond` API change (`accept:false` removal) is a contract change to a shipped endpoint —
  but no released client depends on a decline result yet (v2 isn't launched), so it's safe to change
  in place rather than supersede. Confirm no client calls `accept:false`.

## Notes

Shipped in one PR (#461), three commits: schema+migration, backend service+routes, client.

- **Migration (0007) hand-edited.** drizzle-kit's generated enum-swap cast `status::friendship_status`
  *after* dropping `declined` — which would throw on any existing `declined` row. Moved the
  `UPDATE … SET status='requested', ignored_at=now() WHERE status='declined'` to run while the
  column is text, before the re-cast. No edge is lost; a past decline becomes a silent ignore.
- **`GET /v1/ignored` is the shared aggregator** — returns `{items:[{type, …}]}` mixing
  `friend_request` + `want_invite` (the want-invite ignore from `v2-wants-core` now has its recovery
  home). Extensible by `type` without a new endpoint per kind.
- **Contract change in place, not superseded:** `PUT /requests/:id` now enum-restricts `accept` to
  `true` (decline is gone). Safe because v2 isn't launched — no released client sends `accept:false`.

## Follow-ups

- **`ignored_at` not serialized on friend-request ignored items** — the screen shows who+context,
  which is enough; add the timestamp to the serializer if the UI ever needs "ignored 3d ago".
- **None** otherwise — blocking remains a separate future plan (ignore ≠ block, as documented).
