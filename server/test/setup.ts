// bun test preload (see bunfig.toml). Runs once before any test file.
//
// Ensures tests target a dedicated test database — never the dev database
// (squadquest_v2). Defaults are applied with ??= so an explicit DATABASE_URL
// (CI, or `bin/test`) always wins; in that case this only fills in the other
// env knobs and migrates whatever DB was given.
import postgres from 'postgres'
import { drizzle } from 'drizzle-orm/postgres-js'
import { migrate } from 'drizzle-orm/postgres-js/migrator'

const DEFAULT_TEST_URL =
  'postgres://squadquest:squadquest@localhost:5532/squadquest_test'

// Whether we're using our own default (vs. an externally provided URL like CI's).
const usingDefault = process.env.DATABASE_URL === undefined

process.env.DATABASE_URL ??= DEFAULT_TEST_URL
process.env.JWT_SECRET ??= 'test-secret-min-32-chars-xxxxxxxxxxxxx'
process.env.MIN_SUPPORTED_BUILD ??= '0'
process.env.NODE_ENV ??= 'test'

const url = process.env.DATABASE_URL

// When we own the default, the test DB may not exist yet — create it by
// connecting to the maintenance `postgres` database first. (CI provides its own
// already-created DB, so skip this there.)
if (usingDefault) {
  const target = new URL(url)
  const dbName = target.pathname.slice(1)
  const adminUrl = new URL(url)
  adminUrl.pathname = '/postgres'

  const admin = postgres(adminUrl.toString(), { max: 1 })
  try {
    const rows = await admin`SELECT 1 FROM pg_database WHERE datname = ${dbName}`
    if (rows.length === 0) {
      // dbName is derived from our own constant, not user input.
      await admin.unsafe(`CREATE DATABASE ${dbName}`)
    }
  } finally {
    await admin.end({ timeout: 5 })
  }
}

// Migrate the test DB up to the current schema (idempotent).
const sql = postgres(url, { max: 1 })
try {
  await migrate(drizzle(sql), { migrationsFolder: './migrations' })
} finally {
  await sql.end({ timeout: 5 })
}
