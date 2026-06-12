import { afterAll, beforeAll, expect, test } from 'bun:test'
import Fastify, { type FastifyInstance } from 'fastify'

// Verifies the curated official-topics seed migration (0009). We run the actual
// migration SQL against a cleaned topic table so the test tracks the real file
// rather than a copy. See plans/v2-activity-types-seed.md.

const { app } = await import('../src/app.ts')

let server: FastifyInstance
const SEED_SQL = await Bun.file(
  new URL('../migrations/0009_seed_official_topics.sql', import.meta.url),
).text()
const EXPAND_SQL = await Bun.file(
  new URL('../migrations/0011_expand_official_topics.sql', import.meta.url),
).text()

beforeAll(async () => {
  server = Fastify({ logger: false })
  await server.register(app)
  await server.ready()
})
afterAll(async () => {
  await server.close()
})

test('base seed inserts the curated official set and is idempotent', async () => {
  // Start from a clean slate, then apply the base seed twice.
  await server.sql`truncate activity, want, friendship, profile, topic cascade`
  await server.sql.unsafe(SEED_SQL)
  await server.sql.unsafe(SEED_SQL) // re-run: must be a no-op

  const rows = await server.sql<{ label: string; kind: string }[]>`
    select label, kind from topic`
  expect(rows.length).toBe(23)
  expect(rows.every((r) => r.kind === 'official')).toBe(true)
  const labels = rows.map((r) => r.label)
  expect(labels).toContain('Go Hiking')
  expect(labels).toContain('Play Basketball')
})

test('expansion backfills categories + adds curated topics; idempotent', async () => {
  await server.sql`truncate activity, want, friendship, profile, topic cascade`
  await server.sql.unsafe(SEED_SQL)
  await server.sql.unsafe(EXPAND_SQL)
  await server.sql.unsafe(EXPAND_SQL) // re-run: no-op

  const rows = await server.sql<{ label: string; kind: string; category: string | null }[]>`
    select label, kind, category from topic`
  // 23 base + 30 additions
  expect(rows.length).toBe(53)
  expect(rows.every((r) => r.kind === 'official')).toBe(true)
  // every topic now has a category (base backfilled + additions carry one)
  expect(rows.every((r) => r.category !== null)).toBe(true)
  const byLabel = new Map(rows.map((r) => [r.label, r.category]))
  expect(byLabel.get('Go Hiking')).toBe('Outdoors') // backfilled
  expect(byLabel.get('Do Yoga')).toBe('Sports') // added
  expect(byLabel.get('Join a Protest')).toBe('Civic') // added, new category
  expect(byLabel.get('Go to a Concert')).toBe('Music') // added, new category
})
