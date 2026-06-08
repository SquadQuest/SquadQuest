# contracts/

Edge adapters: per-build request parsers + response serializers that map the
current domain model to the stable wire shapes. This is where version logic lives
(additive / tolerant-reader; break by superseding). See
`specs/api/conventions.md` (the `/v1/ideas` worked example).
