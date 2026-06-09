import { afterAll, beforeAll, expect, test } from 'bun:test'
import Fastify, { type FastifyInstance } from 'fastify'

// Test env defaults (CI provides a Postgres service; locally use docker-compose
// on 5532). Set before importing the app so @fastify/env picks them up.
process.env.DATABASE_URL ??=
  'postgres://squadquest:squadquest@localhost:5532/squadquest_v2'
process.env.JWT_SECRET ??= 'test-secret-min-32-chars-xxxxxxxxxxxxx'
process.env.MIN_SUPPORTED_BUILD = '500'

const { app } = await import('../src/app.ts')

const logs: Array<Record<string, unknown>> = []
let server: FastifyInstance

beforeAll(async () => {
  server = Fastify({
    logger: {
      level: 'info',
      stream: {
        write: (s: string) => {
          try {
            logs.push(JSON.parse(s))
          } catch {
            /* ignore */
          }
        },
      },
    },
  })
  await server.register(app)
  await server.ready()
  await server.sql`truncate profile, friendship, topic, topic_subscription, otp_code, refresh_token cascade`
})

afterAll(async () => {
  await server.close()
})

function lastOtp(): string {
  const entry = [...logs].reverse().find((l) => typeof l.code === 'string')
  if (!entry) throw new Error('no OTP code logged')
  return entry.code as string
}

async function login(phone: string) {
  await server.inject({
    method: 'POST',
    url: '/v1/auth/otp/request',
    payload: { phone },
  })
  const verify = await server.inject({
    method: 'POST',
    url: '/v1/auth/otp/verify',
    payload: { phone, code: lastOtp() },
  })
  return verify
}

test('otp → verify creates a fresh profile and issues tokens', async () => {
  const res = await login('215-555-0100')
  expect(res.statusCode).toBe(200)
  const body = res.json()
  expect(body.access_token).toBeString()
  expect(body.refresh_token).toBeString()
  expect(body.claimed_v1).toBe(false) // brand-new user, no shell
  expect(body.profile.phone).toBe('+12155550100') // normalized to E.164
})

test('GET /v1/me requires auth and returns the profile', async () => {
  const { access_token } = (await login('215-555-0101')).json()

  const unauth = await server.inject({ method: 'GET', url: '/v1/me' })
  expect(unauth.statusCode).toBe(401)
  expect(unauth.json().error.code).toBe('unauthorized')

  const me = await server.inject({
    method: 'GET',
    url: '/v1/me',
    headers: { authorization: `Bearer ${access_token}` },
  })
  expect(me.statusCode).toBe(200)
  expect(me.json().phone).toBe('+12155550101')
})

test('claim-on-login: verifying an unclaimed shell sets claimed_v1', async () => {
  await server.sql`insert into profile (phone, first_name, claimed_at) values ('+12155559999', 'Dana', null)`
  const body = (await login('+12155559999')).json()
  expect(body.claimed_v1).toBe(true)
  expect(body.profile.first_name).toBe('Dana')
})

test('GET /v1/friends returns the accepted graph, flagging unclaimed friends', async () => {
  const me = (await login('215-555-0102')).json()
  const meId = me.profile.id
  const [shell] = await server.sql`
    insert into profile (phone, first_name, claimed_at)
    values ('+12155558888', 'Unclaimed', null) returning id`
  await server.sql`
    insert into friendship (requester, requestee, status)
    values (${meId}, ${shell.id}, 'accepted')`

  const res = await server.inject({
    method: 'GET',
    url: '/v1/friends',
    headers: { authorization: `Bearer ${me.access_token}` },
  })
  expect(res.statusCode).toBe(200)
  const items = res.json().items
  expect(items).toHaveLength(1)
  expect(items[0].first_name).toBe('Unclaimed')
  expect(items[0].on_v2).toBe(false)
})

test('426 below the supported build floor (MIN_SUPPORTED_BUILD=500)', async () => {
  const below = await server.inject({
    method: 'GET',
    url: '/v1/health',
    headers: { 'x-squadquest-client': 'ios/1.0.0+100' },
  })
  expect(below.statusCode).toBe(426)
  expect(below.json().upgrade.min_build).toBe(500)

  const ok = await server.inject({
    method: 'GET',
    url: '/v1/health',
    headers: { 'x-squadquest-client': 'ios/2.0.0+600' },
  })
  expect(ok.statusCode).toBe(200)
})

test('refresh rotates and logout revokes', async () => {
  const { refresh_token } = (await login('215-555-0103')).json()

  const refreshed = await server.inject({
    method: 'POST',
    url: '/v1/auth/refresh',
    payload: { refresh_token },
  })
  expect(refreshed.statusCode).toBe(200)
  expect(refreshed.json().refresh_token).not.toBe(refresh_token) // rotated

  // old token is now revoked
  const reuse = await server.inject({
    method: 'POST',
    url: '/v1/auth/refresh',
    payload: { refresh_token },
  })
  expect(reuse.statusCode).toBe(401)
})
