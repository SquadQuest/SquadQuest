# API: Uploads

Signed-URL image uploads. The client requests an upload target, **PUTs the bytes directly to
the object store** (the API never proxies image bytes — see
[conventions §Storage](conventions.md#storage-photos)), then references the returned key/URL on
the owning resource. Reads are **public, unguessable-key** URLs. Authenticated.

## POST /v1/uploads

Request a signed target for one image.

- **Request:** `{ "kind": "profile" | "community" | "message", "content_type": "image/jpeg" | "image/png" | "image/webp" }`
- **Response:** `200`

  ```jsonc
  {
    "key": "profile/3f2a…​.jpg",                                   // store this on the resource (or its public_url)
    "upload_url": "https://storage.googleapis.com/…X-Goog-Signature=…", // V4 signed PUT, ~10 min TTL
    "public_url": "https://storage.googleapis.com/<bucket>/<key>"  // stable, world-readable
  }
  ```

- **Client flow:** `PUT` the bytes to `upload_url` with the same `Content-Type`, then set the
  resource's photo/attachment to `public_url` (e.g. `PATCH /v1/me { "photo": "<public_url>" }`).
- **Errors:** `invalid_upload_kind`, `unsupported_content_type` (400); `storage_unavailable`
  (503, when the server has no bucket configured — local dev without GCS).

## Notes

- **Public-with-unguessable-key**, not signed reads: keys embed a uuid, objects are
  world-readable, serialized resources return the plain `public_url`. No per-request read
  signing. Don't store anything sensitive here.
- `kind` only scopes the key prefix (`profile/`, `community/`, `message/`); it doesn't grant or
  check ownership of the eventual resource — the owning endpoint does that when the key is set.
- Allowed types are a narrow image allow-list; widen deliberately.

## Principles

**Inherited:**

- [The client binds to the versioned API, never the schema](../principles.md#the-client-binds-to-the-versioned-api-never-the-schema)
  — clients talk to `/v1/uploads` + the owning resource, not to GCS APIs; the storage backend
  (GCS today) is swappable behind this contract.
