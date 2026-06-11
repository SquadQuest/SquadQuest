---
status: planned
depends: [v2-storage-media]
specs: []
issues: []
pr:
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

- [ ] client: attach an image to a squad message + a thread reply; both post with attachments;
      thumbnails render on the tile; photo-only (no text) works. `flutter analyze` + widget tests.

## Risks / unknowns

- The squad composer is inline + stateless-ish; adding pending-attachment state is the main
  surgery. Thread reply input is separate — do both or sequence them.
- Confirm the client `Message` model carries `attachments` (server returns them now).

## Notes

(closeout)

## Follow-ups

(closeout)
