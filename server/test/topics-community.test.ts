import { afterAll, beforeAll, beforeEach, expect, test } from 'bun:test'
import Fastify, { type FastifyInstance } from 'fastify'

// Community activity types: create (dedicated + on-the-fly), normalized-match
// reuse, official-first listing + search. See specs/api/topics.md.

const { app } = await import('../src/app.ts')

let server: FastifyInstance

async function makeUser(phone: string) {
  const [row] = await server.sql<{ id: string }[]>`
    insert into profile (phone, first_name, claimed_at)
    values (${phone}, ${phone}, now()) returning id`
  const token = server.signAccessToken(row.id)
  return { id: row.id, auth: { authorization: `Bearer ${token}` } }
}

beforeAll(async () => {
  server = Fastify({ logger: false })
  await server.register(app)
  await server.ready()
})
afterAll(async () => {
  await server.close()
})
beforeEach(async () => {
  await server.sql`truncate activity, want, friendship, profile, topic cascade`
  // one official seed to test official-first ordering + reuse-across-tiers
  await server.sql`insert into topic (noun, verb, label, kind) values ('Hiking','Go','Go Hiking','official')`
})

test('POST /v1/topics creates a community type with created_by', async () => {
  const user = await makeUser('+12150006000')
  const res = await server.inject({
    method: 'POST',
    url: '/v1/topics',
    headers: user.auth,
    payload: { label: 'Disc Golf' },
  })
  expect(res.statusCode).toBe(201)
  expect(res.json().label).toBe('Disc Golf')
  expect(res.json().kind).toBe('community')

  const [row] = await server.sql<{ created_by: string; kind: string }[]>`
    select created_by, kind from topic where label = 'Disc Golf'`
  expect(row.created_by).toBe(user.id)
})

test('normalized-match reuse returns the existing topic (200, no dup)', async () => {
  const user = await makeUser('+12150006010')
  // matches the seeded official "Go Hiking"? No — different label. Test reuse of a
  // community one we just made, with messy casing/punctuation.
  await server.inject({
    method: 'POST',
    url: '/v1/topics',
    headers: user.auth,
    payload: { label: 'Pickleball' },
  })
  const reuse = await server.inject({
    method: 'POST',
    url: '/v1/topics',
    headers: user.auth,
    payload: { label: '  pickleball! ' },
  })
  expect(reuse.statusCode).toBe(200) // reused, not created
  const [{ n }] = await server.sql<{ n: number }[]>`
    select count(*)::int as n from topic where lower(label) like 'pickleball%'`
  expect(n).toBe(1) // only one row despite two POSTs
})

test('GET /v1/topics is official-first + search filters', async () => {
  const user = await makeUser('+12150006020')
  await server.inject({
    method: 'POST',
    url: '/v1/topics',
    headers: user.auth,
    payload: { label: 'Archery' }, // community, alphabetically before "Go Hiking"
  })
  const list = await server.inject({ method: 'GET', url: '/v1/topics', headers: user.auth })
  const items = list.json().items
  // official "Go Hiking" comes first despite "Archery" sorting earlier alphabetically.
  expect(items[0].label).toBe('Go Hiking')
  expect(items[0].kind).toBe('official')

  const search = await server.inject({
    method: 'GET',
    url: '/v1/topics?search=arch',
    headers: user.auth,
  })
  expect(search.json().items).toHaveLength(1)
  expect(search.json().items[0].label).toBe('Archery')
})

test('on-the-fly: posting an idea with activity_type_label creates + uses it', async () => {
  const user = await makeUser('+12150006030')
  const res = await server.inject({
    method: 'POST',
    url: '/v1/ideas',
    headers: user.auth,
    payload: { activity_type_label: 'Kubb', audience: { kind: 'all_friends' } },
  })
  expect(res.statusCode).toBe(201)
  expect(res.json().activity_type.label).toBe('Kubb')

  const [t] = await server.sql<{ kind: string; created_by: string }[]>`
    select kind, created_by from topic where label = 'Kubb'`
  expect(t.kind).toBe('community')
  expect(t.created_by).toBe(user.id)

  // posting again with the same label reuses the topic (no dup)
  await server.inject({
    method: 'POST',
    url: '/v1/ideas',
    headers: user.auth,
    payload: { activity_type_label: 'kubb', audience: { kind: 'all_friends' } },
  })
  const [{ n }] = await server.sql<{ n: number }[]>`
    select count(*)::int as n from topic where lower(label) = 'kubb'`
  expect(n).toBe(1)
})
