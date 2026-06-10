import { afterAll, beforeAll, beforeEach, expect, test } from 'bun:test'
import Fastify, { type FastifyInstance } from 'fastify'

process.env.DATABASE_URL ??=
  'postgres://squadquest:squadquest@localhost:5532/squadquest_v2'
process.env.JWT_SECRET ??= 'test-secret-min-32-chars-xxxxxxxxxxxxx'
process.env.MIN_SUPPORTED_BUILD = '0'

const { app } = await import('../src/app.ts')

let server: FastifyInstance

async function makeUser(phone: string, firstName: string | null = phone) {
  const [row] = await server.sql<{ id: string }[]>`
    insert into profile (phone, first_name, claimed_at)
    values (${phone}, ${firstName}, now()) returning id`
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
  await server.sql`truncate profile cascade`
})

test('send-by-phone to a stranger creates an unclaimed shell + a requested edge', async () => {
  const alice = await makeUser('+12150001000')

  const res = await server.inject({
    method: 'POST',
    url: '/v1/friends/requests',
    headers: alice.auth,
    payload: { phone: '+12150009999' },
  })
  expect(res.statusCode).toBe(201)
  expect(res.json()).toEqual({ status: 'requested' })

  // A shell was created (on_v2:false in the outgoing request view).
  const reqs = (
    await server.inject({ method: 'GET', url: '/v1/friends/requests', headers: alice.auth })
  ).json()
  expect(reqs.incoming).toHaveLength(0)
  expect(reqs.outgoing).toHaveLength(1)
  expect(reqs.outgoing[0].profile.on_v2).toBe(false)

  // Not yet connected.
  const friends = (
    await server.inject({ method: 'GET', url: '/v1/friends', headers: alice.auth })
  ).json()
  expect(friends.items).toHaveLength(0)
})

test('a request is incoming for the target; accepting connects both ways', async () => {
  const alice = await makeUser('+12150001010')
  const bob = await makeUser('+12150001011')

  await server.inject({
    method: 'POST',
    url: '/v1/friends/requests',
    headers: alice.auth,
    payload: { phone: '+12150001011' },
  })

  const bobReqs = (
    await server.inject({ method: 'GET', url: '/v1/friends/requests', headers: bob.auth })
  ).json()
  expect(bobReqs.incoming).toHaveLength(1)
  expect(bobReqs.incoming[0].profile.id).toBe(alice.id)
  const requestId = bobReqs.incoming[0].id

  const accepted = await server.inject({
    method: 'PUT',
    url: `/v1/friends/requests/${requestId}`,
    headers: bob.auth,
    payload: { accept: true },
  })
  expect(accepted.statusCode).toBe(200)
  expect(accepted.json()).toEqual({ status: 'accepted' })

  // Both see each other in GET /friends.
  const aliceFriends = (
    await server.inject({ method: 'GET', url: '/v1/friends', headers: alice.auth })
  ).json()
  expect(aliceFriends.items.map((f: { id: string }) => f.id)).toEqual([bob.id])
  const bobFriends = (
    await server.inject({ method: 'GET', url: '/v1/friends', headers: bob.auth })
  ).json()
  expect(bobFriends.items.map((f: { id: string }) => f.id)).toEqual([alice.id])

  // The request is no longer pending for either side.
  const bobReqsAfter = (
    await server.inject({ method: 'GET', url: '/v1/friends/requests', headers: bob.auth })
  ).json()
  expect(bobReqsAfter.incoming).toHaveLength(0)
})

test('a reciprocal send auto-accepts (no duplicate edge)', async () => {
  const alice = await makeUser('+12150001020')
  const bob = await makeUser('+12150001021')

  await server.inject({
    method: 'POST',
    url: '/v1/friends/requests',
    headers: alice.auth,
    payload: { phone: '+12150001021' },
  })

  // Bob "sends" to Alice → treated as accept.
  const res = await server.inject({
    method: 'POST',
    url: '/v1/friends/requests',
    headers: bob.auth,
    payload: { phone: '+12150001020' },
  })
  expect(res.statusCode).toBe(200)
  expect(res.json()).toEqual({ status: 'accepted' })

  const bobFriends = (
    await server.inject({ method: 'GET', url: '/v1/friends', headers: bob.auth })
  ).json()
  expect(bobFriends.items.map((f: { id: string }) => f.id)).toEqual([alice.id])

  // Exactly one edge for the pair.
  const [{ count }] = await server.sql<{ count: number }[]>`
    select count(*)::int as count from friendship`
  expect(count).toBe(1)
})

test('re-sending an existing request is idempotent (still one requested edge)', async () => {
  const alice = await makeUser('+12150001030')
  await makeUser('+12150001031')

  for (let i = 0; i < 2; i++) {
    const res = await server.inject({
      method: 'POST',
      url: '/v1/friends/requests',
      headers: alice.auth,
      payload: { phone: '+12150001031' },
    })
    expect(res.json()).toEqual({ status: 'requested' })
  }
  const [{ count }] = await server.sql<{ count: number }[]>`
    select count(*)::int as count from friendship`
  expect(count).toBe(1)
})

test('declining leaves no connection; the pair can re-request later', async () => {
  const alice = await makeUser('+12150001040')
  const bob = await makeUser('+12150001041')

  await server.inject({
    method: 'POST',
    url: '/v1/friends/requests',
    headers: alice.auth,
    payload: { phone: '+12150001041' },
  })
  const reqId = (
    await server.inject({ method: 'GET', url: '/v1/friends/requests', headers: bob.auth })
  ).json().incoming[0].id

  const declined = await server.inject({
    method: 'PUT',
    url: `/v1/friends/requests/${reqId}`,
    headers: bob.auth,
    payload: { accept: false },
  })
  expect(declined.json()).toEqual({ status: 'declined' })

  // No connection, nothing pending.
  expect(
    (await server.inject({ method: 'GET', url: '/v1/friends', headers: alice.auth })).json()
      .items,
  ).toHaveLength(0)
  expect(
    (await server.inject({ method: 'GET', url: '/v1/friends/requests', headers: alice.auth }))
      .json().outgoing,
  ).toHaveLength(0)

  // Re-request reopens it (decline is not a block) — still one edge.
  const reopened = await server.inject({
    method: 'POST',
    url: '/v1/friends/requests',
    headers: alice.auth,
    payload: { phone: '+12150001041' },
  })
  expect(reopened.json()).toEqual({ status: 'requested' })
  const [{ count }] = await server.sql<{ count: number }[]>`
    select count(*)::int as count from friendship`
  expect(count).toBe(1)
})

test('only the requestee may respond; others get 404', async () => {
  const alice = await makeUser('+12150001050')
  const bob = await makeUser('+12150001051')
  const carol = await makeUser('+12150001052')

  await server.inject({
    method: 'POST',
    url: '/v1/friends/requests',
    headers: alice.auth,
    payload: { phone: '+12150001051' },
  })
  const reqId = (
    await server.inject({ method: 'GET', url: '/v1/friends/requests', headers: bob.auth })
  ).json().incoming[0].id

  // Carol (uninvolved) cannot respond.
  expect(
    (
      await server.inject({
        method: 'PUT',
        url: `/v1/friends/requests/${reqId}`,
        headers: carol.auth,
        payload: { accept: true },
      })
    ).statusCode,
  ).toBe(404)

  // The requester (Alice) cannot accept her own outgoing request either.
  expect(
    (
      await server.inject({
        method: 'PUT',
        url: `/v1/friends/requests/${reqId}`,
        headers: alice.auth,
        payload: { accept: true },
      })
    ).statusCode,
  ).toBe(404)
})

test('cannot friend yourself', async () => {
  const alice = await makeUser('+12150001060')
  const res = await server.inject({
    method: 'POST',
    url: '/v1/friends/requests',
    headers: alice.auth,
    payload: { phone: '+12150001060' },
  })
  expect(res.statusCode).toBe(400)
  expect(res.json().error.code).toBe('cannot_self_request')
})

test('PATCH /v1/me sets the name; GET reflects it; blank first_name is rejected', async () => {
  const [row] = await server.sql<{ id: string }[]>`
    insert into profile (phone, claimed_at) values (${'+12150001070'}, now()) returning id`
  const auth = { authorization: `Bearer ${server.signAccessToken(row.id)}` }

  // Fresh profile needs onboarding.
  expect(
    (await server.inject({ method: 'GET', url: '/v1/me', headers: auth })).json().first_name,
  ).toBeNull()

  const patched = await server.inject({
    method: 'PATCH',
    url: '/v1/me',
    headers: auth,
    payload: { first_name: 'Chris', last_name: 'Alfano' },
  })
  expect(patched.statusCode).toBe(200)
  expect(patched.json().first_name).toBe('Chris')
  expect(patched.json().last_name).toBe('Alfano')

  // Persisted.
  expect(
    (await server.inject({ method: 'GET', url: '/v1/me', headers: auth })).json().first_name,
  ).toBe('Chris')

  // Blank first_name is rejected.
  const blank = await server.inject({
    method: 'PATCH',
    url: '/v1/me',
    headers: auth,
    payload: { first_name: '   ' },
  })
  expect(blank.statusCode).toBe(400)
  expect(blank.json().error.code).toBe('first_name_required')
})
