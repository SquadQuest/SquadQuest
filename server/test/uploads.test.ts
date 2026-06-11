import { afterAll, beforeAll, beforeEach, expect, test } from 'bun:test'
import Fastify, { type FastifyInstance } from 'fastify'

// No MEDIA_BUCKET in the test env → the uploads endpoint should 503 rather than
// attempt to sign (which would need GCS creds). Validation + auth still apply.
// (A live signed-URL round-trip is covered manually against the deployed service.)

const { app } = await import('../src/app.ts')

let server: FastifyInstance

async function makeUser(phone: string) {
  const [row] = await server.sql<{ id: string }[]>`
    insert into profile (phone, first_name, claimed_at)
    values (${phone}, ${phone}, now()) returning id`
  return { auth: { authorization: `Bearer ${server.signAccessToken(row.id)}` } }
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
  await server.sql`truncate profile cascade`
})

test('POST /v1/uploads requires auth', async () => {
  const res = await server.inject({
    method: 'POST',
    url: '/v1/uploads',
    payload: { kind: 'profile', content_type: 'image/jpeg' },
  })
  expect(res.statusCode).toBe(401)
})

test('POST /v1/uploads returns 503 when storage is not configured (no MEDIA_BUCKET)', async () => {
  const user = await makeUser('+12155558000')
  const res = await server.inject({
    method: 'POST',
    url: '/v1/uploads',
    headers: user.auth,
    payload: { kind: 'profile', content_type: 'image/jpeg' },
  })
  expect(res.statusCode).toBe(503)
  expect(res.json().error.code).toBe('storage_unavailable')
})

test('PATCH /v1/me accepts a photo URL/key and serializes it', async () => {
  const user = await makeUser('+12155558010')
  const url = 'https://storage.googleapis.com/squadquest-v2-media/profile/abc.jpg'
  const res = await server.inject({
    method: 'PATCH',
    url: '/v1/me',
    headers: user.auth,
    payload: { photo: url },
  })
  expect(res.statusCode).toBe(200)
  expect(res.json().photo).toBe(url)

  // clearing
  const cleared = await server.inject({
    method: 'PATCH',
    url: '/v1/me',
    headers: user.auth,
    payload: { photo: '' },
  })
  expect(cleared.json().photo).toBeNull()
})
