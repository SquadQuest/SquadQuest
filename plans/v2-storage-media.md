---
status: planned
depends: [v2-storage]
specs:
  - specs/api/uploads.md
  - specs/api/communities.md
  - specs/api/messages.md
issues: []
pr:
---

# Plan: v2 storage media (community photos + message attachments)

> Split out of [`v2-storage`](v2-storage.md), which built the reusable upload pipeline
> (`POST /v1/uploads`) + profile photos. These two surfaces are thin consumers of it; they're
> separated only because each needs a **schema migration**.

## Scope

Extend the (already-built) signed-URL upload pipeline to the two remaining image surfaces.

**In:**

- **Community photos:** `community.photo` column (migration); `POST`/`PATCH /v1/communities`
  accept `photo`; serializer returns the public URL; leader create/edit form uploads (kind
  `community`).
- **Message attachments:** an attachments store (migration — `message.attachments` jsonb array
  of `{key,url}`, or a `message_attachment` table); message-post + thread-reply accept attachment
  keys; serializer returns real URLs (replacing the `attachments: [] // until storage lands` stub
  in `contracts/message.ts`); composer attach (kind `message`).

**Out:** image transforms/thumbnails; the upload pipeline itself (done in `v2-storage`); changing
the public-key serving model.

## Implements

`specs/api/uploads.md` (reuses the endpoint), `specs/api/communities.md` (community `photo`),
`specs/api/messages.md` (attachments). Spec touch-ups: document `photo` on community write/read
and the attachments shape on messages.

## Approach

Absorbed from `v2-storage`'s deferral. Both surfaces just store an upload's `public_url` (or key)
and serialize it back — no new storage code, only schema + route/serializer/client wiring per
surface:

- **Community:** migration adds `community.photo text`; thread it through `CommunityService`
  create/update + `serializeCommunity`; client `CreateCommunityScreen` gains an image picker that
  uploads (kind `community`) then sets `photo`.
- **Messages:** migration adds attachments storage; `MessageService` post/reply accept
  `attachment_keys`; `serializeMessage` returns `[{key,url}]` from stored keys (drop the stub);
  client composer attaches images (kind `message`). Decide jsonb-column vs join-table in
  `data-model.md` first (lean jsonb for simplicity given small N).

## Validation

- [ ] migrations apply (community.photo; message attachments) — `migrate-on-startup` stays green.
- [ ] `bun test` + type-check: community create/edit with a photo serializes the URL; message
      post with attachment keys serializes `[{key,url}]`; empty/no attachments → `[]`.
- [ ] client: community form photo upload; message composer attach; both render.
- [ ] CI green; deploy.

## Risks / unknowns

- **Attachments model** (jsonb vs join table) — settle in `data-model.md` before coding; jsonb is
  simpler and matches the current serializer shape, a table is cleaner if attachments grow
  metadata. Don't over-build.
- **No ownership check on `kind`** (by design — see uploads.md); the owning endpoint must still
  validate the caller may set the photo (leader for community, sender for message).
- Two additive migrations — order them, keep startup migration happy.

## Notes

(closeout)

## Follow-ups

(closeout)
