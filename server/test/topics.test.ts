import { afterAll, beforeAll, beforeEach, expect, test } from 'bun:test'
import Fastify, { type FastifyInstance } from 'fastify'

process.env.DATABASE_URL ??=
  'postgres://squadquest:squadquest@localhost:5532/squadquest_v2'
process.env.JWT_SECRET ??= 'test-secret-min-32-chars-xxxxxxxxxxxxx'
process.env.MIN_SUPPORTED_BUILD = '0'

const { app } = await import('../src/app.ts')

let server: FastifyInstance

async function makeUser(phone: string) {
  const [row] = await server.sql<{ id: string }[]>`
    insert into profile (phone, first_name, claimed_at)
    values (${phone}, ${phone}, now()) returning id`
  const token = server.signAccessToken(row.id)
  return { auth: { authorization: `Bearer ${token}` } }
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
  await server.sql`truncate activity, friendship, profile, topic cascade`
})

test('GET /v1/topics requires auth', async () => {
  const res = await server.inject({ method: 'GET', url: '/v1/topics' })
  expect(res.statusCode).toBe(401)
})

test('GET /v1/topics lists topics alphabetically by label', async () => {
  await server.sql`insert into topic (noun, verb, label) values ('Hiking', 'Go', 'Go Hiking')`
  await server.sql`insert into topic (noun, verb, label) values ('Paddleboarding', 'Go', 'Boarding')`
  const user = await makeUser('+12150009000')

  const res = await server.inject({
    method: 'GET',
    url: '/v1/topics',
    headers: user.auth,
  })
  expect(res.statusCode).toBe(200)
  const items = res.json().items
  expect(items).toHaveLength(2)
  expect(items.map((t: { label: string }) => t.label)).toEqual(['Boarding', 'Go Hiking'])
  expect(items[0]).toHaveProperty('id')
  expect(items[0]).toHaveProperty('noun')
  expect(items[0]).toHaveProperty('verb')
})
