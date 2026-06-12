---
status: done
depends: [v2-storage-media]
specs: []
issues: []
pr: 463
---

# Plan: v2 message-attachments client UI

> **Backlog stub** (`status: planned`). The backend + shared upload primitive already exist
> (`v2-storage-media`, `v2-storage`); this is the deferred *client* half. Specs are unchanged
> (`api/messages.md` already documents `attachments`) — this is UI only.

## Scope

Let users attach images to messages and see them, completing the message-attachment surface
whose backend shipped in `v2-storage-media`.

**In:**

- **Compose:** an attach affordance on the squad composer (the inline `_SquadComposer` in
  `timeline_screen.dart`) and on thread replies (`thread_screen.dart`) — reuse the existing
  `PhotoPicker` / `UploadRepository`; pass `attachments: [{key,url}]` to the message post.
- **Render (read path):** show attachment thumbnails on message tiles in the squad timeline +
  thread view (tap to view full).
- Allow **photo-only** messages (backend already permits text-or-attachment).

**Out:** multi-image galleries beyond a simple row; video/non-image; image editing/cropping.

## Implements

No spec change — `specs/api/messages.md` already specifies `attachments`. Pure client wiring
to the existing contract.

## Approach (rough — refine at pickup)

- `MessageRepository.postSquadMessage` / thread reply gain an optional `attachments` arg
  (model already can carry them; confirm the `Message` model parses `attachments`).
- Composer: an image button → `PhotoPicker`-style pick+upload (kind `message`) → hold the
  resulting `{key,url}` until send; show a pending-thumbnail strip.
- Tiles: render `message.attachments` as thumbnails (the read path — needs `Message.attachments`
  in the client model if not already there).

## Validation

- [x] client: attach affordance on the squad composer + thread reply (shared `MessageAttachmentField`);
      both post with attachments; photo-only (no text) works (Send enables on text OR attachment);
      thumbnails render on message tiles + reply rows (`MessageAttachmentThumbs`, tap → full-screen).
      `flutter analyze` clean; suite 33 pass.
- [ ] **(on-device, post-merge)** attach a photo to a squad message + a thread reply; confirm upload
      + thumbnail render end-to-end (the read-path render isn't unit-tested — see Notes).

## Notes

PR #463. Built one reusable `MessageAttachmentField` (pick→upload kind `message`→pending-thumbnail
strip with remove) shared by the inline squad composer and the thread reply input, plus a
`MessageAttachmentThumbs` read-path widget. `Message` model + `MessageRepository` gained
`attachments`; both post paths allow photo-only.

**Test gap (intentional):** rendering a *populated* attachment thumbnail isn't asserted in a widget
test — `NetworkImage` returns HTTP 400 in the Flutter test binding (no real network), which fails
the test even though the widget builds. Same constraint hit + accepted in the profile-photo work;
the read path is covered via MCP / on-device instead. Compose/post is unit-tested.

## Follow-ups

- **Deferred (out per the plan):** multi-image galleries beyond a simple wrapped row; video /
  non-image; crop/edit. None needed for the core surface.
