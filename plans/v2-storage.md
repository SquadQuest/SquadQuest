---
status: in-progress
depends: [v2-backend-infra]
specs:
  - specs/api/conventions.md
  - specs/architecture.md
issues: []
pr:
---

# Plan: v2 storage (photo/media via GCS, signed-URL upload)

## Scope

Object storage for user-supplied images, per `conventions.md` §Storage: client requests an
upload target from the API, **PUTs bytes directly** to GCS (the API never proxies bytes), then
references the returned key; **reads are public-with-unguessable-key** URLs in serialized
resources. Full scope: **profile photos, community photos, and message attachments**.

**In:**

- **Infra:** a public-read GCS bucket (`media.squadquest.app` or `squadquest-v2-media`) in `tf/`,
  world-readable, with the Cloud Run runtime SA able to mint V4 signed PUT URLs (needs
  `roles/iam.serviceAccountTokenCreator` on itself for keyless `signBlob` signing).
- **Shared pipeline (foundation):** `POST /v1/uploads` → `{ key, upload_url, public_url }`
  (signed V4 PUT, short expiry). A `StorageService` (wraps `@google-cloud/storage`) that signs
  upload URLs and builds public URLs. Keys are `<kind>/<uuid>` (unguessable).
- **Profile photos:** `PATCH /v1/me` accepts `photo` (a storage key/url); serialized profile
  returns the public URL. Client: pick image → upload → PATCH.
- **Community photos:** add a `photo` column (migration); `POST`/`PATCH /v1/communities` accept
  it; serializer returns it; leader create/edit form uploads.
- **Message attachments:** add an `attachments` column (migration — jsonb array of `{key,url}`,
  or a `message_attachment` table); message post accepts attachment keys; serializer returns
  real URLs (replacing the `[] until storage lands` stub); client composer attaches.
- Spec: new `specs/api/uploads.md`; touch `profile.md`, `communities.md`, `messages.md`.

**Out:** image resize/thumbnails/transforms; EXIF stripping; per-object signed *reads* (we use
public keys); virus scanning; non-image media; rehosting v1 Supabase-stored avatars (separate
migration concern). Client styling.

## Implements

`specs/api/conventions.md` §Storage (the signed-upload contract) + `architecture.md`
(object store + keys). New `specs/api/uploads.md` for the endpoint.

## Approach

Phase the work so the reusable foundation lands first and each surface is independently
shippable:

- **Phase 1 — foundation (infra + pipeline):** tf bucket + IAM (`signBlob` self-grant on the
  compute SA); `bun add @google-cloud/storage`; `StorageService` + `POST /v1/uploads`; env for
  the bucket name (wired via tf). Tests: uploads returns a well-formed key + public URL; reject
  disallowed content types.
- **Phase 2 — profile photos:** `PATCH /v1/me` photo; client profile-photo picker → upload →
  PATCH (likely a small add to the welcome/profile-edit surface). Proves the pipeline end-to-end.
- **Phase 3 — community photos:** migration (`community.photo`); routes + serializer + leader
  form upload.
- **Phase 4 — message attachments:** migration (attachments); message post + serializer (drop
  the stub) + composer attach.

V4 signed PUT via `@google-cloud/storage` `file.getSignedUrl({version:'v4', action:'write',
contentType, expires})` — works with ADC + IAM `signBlob` on Cloud Run (no key file). Public
read URL: `https://storage.googleapis.com/<bucket>/<key>`. Validate content type
(image/jpeg|png|webp) and cap size via the signed URL's conditions where practical.

## Validation

- [ ] `bun test` + type-check: `POST /v1/uploads` returns key/upload_url/public_url; content-type
      allow-list enforced; StorageService builds correct public URLs.
- [ ] tf: bucket public-read + SA `signBlob` self-grant applied; `tofu plan` clean.
- [ ] profile: PATCH photo round-trips; serialized profile shows the public URL.
- [ ] community photo + message attachments: migrations applied; create/post with an upload key
      serializes the public URL; client uploads in each surface.
- [ ] CI green; deploy; (live) upload a real image via the signed URL and load it back publicly.

## Risks / unknowns

- **Keyless signing**: V4 signing without a key file requires the runtime SA to sign via IAM
  `signBlob` — grant `roles/iam.serviceAccountTokenCreator` to the compute SA *on itself*, and
  ensure `@google-cloud/storage` uses it (it falls back to signBlob when no private key). Verify
  on Cloud Run, not just locally (local ADC differs).
- **Public bucket exposure**: world-readable means anyone with the key can fetch. Acceptable for
  avatars/community/most attachments (unguessable uuid keys); do NOT put anything sensitive here.
- **Two migrations** (community.photo, message attachments) — additive, low risk, but order them
  and keep `migrate-on-startup` happy.
- **`@google-cloud/storage` is a heavy dep** (vs the no-SDK Twilio approach). Justified: V4
  signing + signBlob fallback is error-prone to hand-roll. Confirm it bundles cleanly in the
  Bun/alpine image.
- Scope is large — Phases 3–4 may split into their own plans if Phase 1–2 reveal friction.

## Notes

(closeout)

## Follow-ups

(closeout)
