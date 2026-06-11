// Standalone migration runner for container startup (migrate-then-serve).
//
// Uses drizzle-orm's programmatic migrator (a production dependency) so the
// image needs neither drizzle-kit (a devDependency) nor a public DB IP — it runs
// inside the VPC and reaches Cloud SQL over its private IP. Reads DATABASE_URL
// from env; applies everything in ./migrations idempotently, then exits.
import postgres from 'postgres'
import { drizzle } from 'drizzle-orm/postgres-js'
import { migrate } from 'drizzle-orm/postgres-js/migrator'

const url = process.env.DATABASE_URL
if (!url) {
  console.error('migrate: DATABASE_URL is required')
  process.exit(1)
}

const sql = postgres(url, { max: 1 })
try {
  await migrate(drizzle(sql), { migrationsFolder: './migrations' })
  console.log('migrate: up to date')
} catch (err) {
  console.error('migrate: failed', err)
  process.exit(1)
} finally {
  await sql.end({ timeout: 5 })
}
