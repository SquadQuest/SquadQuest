// postgres.js cannot express a unix socket in a connection URL — ?host= and
// ?path= query params are ignored and a percent-encoded authority resolves as
// a DNS name (verified empirically against postgres.js 3.x during the 2026-07
// shared-pg cutover). Cloud Run's Cloud SQL mount is a socket dir, so prod
// URLs carry the libpq convention `?host=/cloudsql/<connection>` and this
// helper translates them into an options-object connection. Dev URLs (plain
// TCP against local postgres, no ?host=) pass through to postgres(url)
// untouched — no GCP connector libraries, full dev/prod parity.
import postgres from 'postgres'

export function connectDb(url: string, options: postgres.Options<{}> = {}) {
  const parsed = new URL(url.replace(/^postgres(ql)?:/, 'http:'))
  const socketDir = parsed.searchParams.get('host')

  if (!socketDir?.startsWith('/')) {
    return postgres(url, options)
  }

  return postgres({
    host: socketDir, // leading-slash host = unix socket dir to postgres.js
    database: parsed.pathname.replace(/^\//, ''),
    username: decodeURIComponent(parsed.username),
    password: decodeURIComponent(parsed.password),
    ...options,
  })
}
