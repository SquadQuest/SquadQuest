import { afterAll, beforeAll, beforeEach, expect, test } from 'bun:test'
import Fastify, { type FastifyInstance } from 'fastify'

// Test env is configured by test/setup.ts (bun preload; see bunfig.toml).

const { app } = await import('../src/app.ts')

let server: FastifyInstance

async function makeUser(phone: string) {
  const [row] = await server.sql<{ id: string }[]>`
    insert into profile (phone, first_name, claimed_at)
    values (${phone}, ${phone}, now()) returning id`
  return { id: row.id, auth: { authorization: `Bearer ${server.signAccessToken(row.id)}` } }
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
  await server.sql`truncate community, community_membership, squad, squad_membership, message, profile cascade`
})

const PHOTO = 'https://storage.googleapis.com/squadquest-v2-media/community/abc.png'

test('community photo round-trips through create + edit + serialize', async () => {
  const leader = await makeUser('+12155559000')

  const created = await server.inject({
    method: 'POST',
    url: '/v1/communities',
    headers: leader.auth,
    payload: { name: 'River Flow', photo: PHOTO },
  })
  expect(created.statusCode).toBe(201)
  expect(created.json().photo).toBe(PHOTO)
  const cid = created.json().id

  // visible in discover
  const list = (
    await server.inject({ method: 'GET', url: '/v1/communities', headers: leader.auth })
  ).json().items
  expect(list.find((c: { id: string }) => c.id === cid).photo).toBe(PHOTO)

  // edit clears it
  const edited = await server.inject({
    method: 'PATCH',
    url: `/v1/communities/${cid}`,
    headers: leader.auth,
    payload: { photo: '' },
  })
  expect(edited.statusCode).toBe(200)
})

test('squad message accepts attachments and serializes them', async () => {
  const user = await makeUser('+12155559010')
  const [sq] = await server.sql<{ id: string }[]>`
    insert into squad (name) values (${'Riders'}) returning id`
  await server.sql`
    insert into squad_membership (squad_id, profile_id, role)
    values (${sq.id}, ${user.id}, ${'captain'})`

  const att = [
    { key: 'message/x.jpg', url: 'https://storage.googleapis.com/squadquest-v2-media/message/x.jpg' },
  ]
  const res = await server.inject({
    method: 'POST',
    url: `/v1/squads/${sq.id}/messages`,
    headers: user.auth,
    payload: { body: 'check this out', attachments: att },
  })
  expect(res.statusCode).toBe(201)
  expect(res.json().attachments).toEqual(att)
})

test('photo-only squad message (no body) is allowed; truly empty is rejected', async () => {
  const user = await makeUser('+12155559020')
  const [sq] = await server.sql<{ id: string }[]>`
    insert into squad (name) values (${'Riders'}) returning id`
  await server.sql`
    insert into squad_membership (squad_id, profile_id, role)
    values (${sq.id}, ${user.id}, ${'captain'})`

  const photoOnly = await server.inject({
    method: 'POST',
    url: `/v1/squads/${sq.id}/messages`,
    headers: user.auth,
    payload: {
      attachments: [{ key: 'message/y.png', url: 'https://x/y.png' }],
    },
  })
  expect(photoOnly.statusCode).toBe(201)
  expect(photoOnly.json().body).toBeNull()

  const empty = await server.inject({
    method: 'POST',
    url: `/v1/squads/${sq.id}/messages`,
    headers: user.auth,
    payload: {},
  })
  expect(empty.statusCode).toBe(400)
  expect(empty.json().error.code).toBe('empty_message')
})
