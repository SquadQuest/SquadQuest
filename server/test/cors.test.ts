import { afterAll, beforeAll, expect, test } from 'bun:test'
import Fastify, { type FastifyInstance } from 'fastify'

import { isOriginAllowed, parseAllowedOrigins } from '../src/app.ts'

const { app } = await import('../src/app.ts')

// CORS allow-list resolver (specs/api/conventions.md, behaviors/ci-cd.md).
// Pure-function tested so we don't mutate process-wide NODE_ENV/ALLOWED_ORIGINS.

const prod = parseAllowedOrigins('https://v2.squadquest.app')

test('parseAllowedOrigins: trims, drops empties, handles multi + blank', () => {
  expect([...parseAllowedOrigins(' https://a.app , https://b.app ')]).toEqual([
    'https://a.app',
    'https://b.app',
  ])
  expect([...parseAllowedOrigins('')]).toEqual([])
  expect([...parseAllowedOrigins('  ,  ')]).toEqual([])
})

test('allowed origin is permitted; off-list browser origin is blocked', () => {
  // production posture: no localhost allowance
  expect(isOriginAllowed('https://v2.squadquest.app', prod, false)).toBe(true)
  expect(isOriginAllowed('https://evil.example', prod, false)).toBe(false)
  // a path is not part of an origin — the browser only ever sends the origin,
  // so a preview under v2.squadquest.app/<branch>/ presents this same origin.
})

test('no Origin (native client / curl) is always allowed', () => {
  expect(isOriginAllowed(undefined, prod, false)).toBe(true)
  expect(isOriginAllowed(undefined, parseAllowedOrigins(''), false)).toBe(true)
})

test('localhost allowed only when allowLocalhost (non-production)', () => {
  expect(isOriginAllowed('http://localhost:4000', prod, true)).toBe(true)
  expect(isOriginAllowed('http://localhost', prod, true)).toBe(true)
  expect(isOriginAllowed('https://localhost:8080', prod, true)).toBe(true)
  // in production, localhost is not special
  expect(isOriginAllowed('http://localhost:4000', prod, false)).toBe(false)
})

test('empty allow-list blocks every browser origin (safe default)', () => {
  const none = parseAllowedOrigins('')
  expect(isOriginAllowed('https://v2.squadquest.app', none, false)).toBe(false)
  // but still never blocks a no-Origin request
  expect(isOriginAllowed(undefined, none, false)).toBe(true)
})

// Integration: the preflight must allow mutating verbs. @fastify/cors defaults
// `methods` to GET,HEAD,POST, which silently breaks cross-origin PATCH/PUT/DELETE
// (e.g. PATCH /v1/me) on the web build. Lock that in. See conventions.md (CORS).
test('preflight allows all mutating methods (PATCH/PUT/DELETE)', async () => {
  const server: FastifyInstance = Fastify({ logger: false })
  await server.register(app)
  await server.ready()
  try {
    const res = await server.inject({
      method: 'OPTIONS',
      url: '/v1/me',
      headers: {
        // dev posture (NODE_ENV !== production) → localhost origin is allowed
        origin: 'http://localhost:4000',
        'access-control-request-method': 'PATCH',
      },
    })
    const allowed = (res.headers['access-control-allow-methods'] ?? '') as string
    for (const verb of ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']) {
      expect(allowed).toContain(verb)
    }
    expect(res.headers['access-control-allow-origin']).toBe('http://localhost:4000')
  } finally {
    await server.close()
  }
})
