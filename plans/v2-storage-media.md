---
status: done
depends: [v2-storage]
specs:
  - specs/api/uploads.md
  - specs/api/communities.md
  - specs/api/messages.md
issues: []
pr: 439
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

- [x] migration 0005 (community.photo; message.attachments jsonb) applies — verified clean on
      prod via migrate-on-startup (deploy green, `/v1/health` 200 after).
- [x] `bun test` + type-check: community create/edit photo round-trips + serializes; squad
      message with attachments serializes `[{key,url}]`; photo-only allowed, empty → `empty_message`.
      Suite **50/50**. [PR #439]
- [x] client: community form photo upload (PR #440). **Message composer attach deferred** —
      see Follow-ups.
- [x] CI green; deployed (migration ran on prod).

## Risks / unknowns

- **Attachments model** (jsonb vs join table) — settle in `data-model.md` before coding; jsonb is
  simpler and matches the current serializer shape, a table is cleaner if attachments grow
  metadata. Don't over-build.
- **No ownership check on `kind`** (by design — see uploads.md); the owning endpoint must still
  validate the caller may set the photo (leader for community, sender for message).
- Two additive migrations — order them, keep startup migration happy.

## Notes

Backend in **PR #439** (migration 0005 + community.photo + message.attachments jsonb; serializer
drops the `[]` stub; a message now needs text-or-attachment). Settled the attachments model as a
**jsonb column** `[{key,url}]` (not a join table) — matches the serializer shape, simplest for
small N; `data-model.md` already anticipated object-store keys. Client community-photo + the
shared `PhotoPicker`/`UploadRepository` primitive in **PR #440** (alongside profile photos, which
were `v2-storage`'s client side).

The signed PUT goes direct to GCS via a **bare Dio** (no `/v1` interceptors) — the signed URL
self-authenticates; routing it through the normal ApiClient would wrongly stamp the auth/build
headers.

## Follow-ups

- **Deferred (client):** the **message-attachment composer**. Backend + the `PhotoPicker`
  primitive are done; the squad composer is an inline `_SquadComposer` (and thread replies a
  separate input) that needs more UI surgery to add an attach affordance + render attachment
  thumbnails on message tiles. Its own follow-up; not blocking — text messaging is unaffected.
- **Tracked as:** rendering attachment thumbnails in the thread/timeline message tiles (read
  path) pairs with the composer work above.
- **None** else — community photos + the attachments contract are complete and deployed.
