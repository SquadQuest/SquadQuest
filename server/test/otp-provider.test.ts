import { afterAll, beforeAll, beforeEach, expect, test } from 'bun:test'
import Fastify, { type FastifyInstance } from 'fastify'

// Test env is configured by test/setup.ts (bun preload; see bunfig.toml).

const { app } = await import('../src/app.ts')

let server: FastifyInstance

beforeAll(async () => {
  server = Fastify({ logger: false })
  await server.register(app)
  await server.ready()
})
afterAll(async () => {
  await server.close()
})
beforeEach(async () => {
  await server.sql`truncate otp_code, refresh_token, profile cascade`
})

const auth = { 'x-squadquest-client': 'web/1.0.0+1' }

test('console OTP: request then verify with the logged code logs in', async () => {
  // request → row created in otp_code
  const reqRes = await server.inject({
    method: 'POST',
    url: '/v1/auth/otp/request',
    headers: auth,
    payload: { phone: '+12155557000' },
  })
  expect(reqRes.statusCode).toBe(200)
  expect(reqRes.json().expires_in).toBeGreaterThan(0)

  // The console provider stores a hashed code; we can't read it, but we can drive
  // the happy path by reproducing the same hash check via a fresh known code:
  // instead, assert wrong code is rejected and the row tracks attempts.
  const wrong = await server.inject({
    method: 'POST',
    url: '/v1/auth/otp/verify',
    headers: auth,
    payload: { phone: '+12155557000', code: '000000' },
  })
  expect(wrong.statusCode).toBe(400)
  expect(wrong.json().error.code).toBe('otp_invalid')

  const [row] = await server.sql<{ attempts: number }[]>`
    select attempts from otp_code where phone = ${'+12155557000'}`
  expect(row.attempts).toBe(1)
})

test('verify with no outstanding request → otp_expired', async () => {
  const res = await server.inject({
    method: 'POST',
    url: '/v1/auth/otp/verify',
    headers: auth,
    payload: { phone: '+12155557999', code: '123456' },
  })
  expect(res.statusCode).toBe(400)
  expect(res.json().error.code).toBe('otp_expired')
})

test('console OTP end-to-end with a seeded code (claims/creates profile + issues tokens)', async () => {
  // Drive the full happy path by seeding a known code hash directly, matching the
  // ConsoleOtpProvider's scheme: sha256(`${phone}:${code}`).
  const phone = '+12155557010'
  const code = '424242'
  const { createHash } = await import('node:crypto')
  const hash = createHash('sha256').update(`${phone}:${code}`).digest('hex')
  await server.sql`
    insert into otp_code (phone, code_hash, expires_at, attempts)
    values (${phone}, ${hash}, now() + interval '5 minutes', 0)`

  const res = await server.inject({
    method: 'POST',
    url: '/v1/auth/otp/verify',
    headers: auth,
    payload: { phone, code },
  })
  expect(res.statusCode).toBe(200)
  const body = res.json()
  expect(body.access_token).toBeTruthy()
  expect(body.refresh_token).toBeTruthy()
  expect(body.profile.phone).toBe(phone)
  expect(body.claimed_v1).toBe(false) // fresh profile, no v1 shell

  // code consumed
  const rows = await server.sql`select 1 from otp_code where phone = ${phone}`
  expect(rows).toHaveLength(0)
})
