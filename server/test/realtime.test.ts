import { afterAll, beforeAll, beforeEach, expect, test } from 'bun:test'
import Fastify, { type FastifyInstance } from 'fastify'

// Exercises the realtime fan-out + per-subscriber visibility gate directly via
// fastify.realtime (an in-process SSE round-trip is awkward to assert; the gate is
// the load-bearing part). See specs/behaviors/realtime.md.

const { app } = await import('../src/app.ts')
import type { RealtimeEvent } from '../src/realtime/index.ts'

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
  await server.sql`truncate activity, message, squad, squad_membership, friendship, profile, topic cascade`
})

// Wait for the NOTIFY round-trip (publish → Postgres → LISTEN → fan-out).
function tick(ms = 150) {
  return new Promise((r) => setTimeout(r, ms))
}

test('publish fans out only to subscribers who pass the visibility gate', async () => {
  const seen: Record<string, RealtimeEvent[]> = { a: [], b: [] }

  // Two subscribers: "a" can see everything, "b" can see nothing.
  const offA = server.realtime.add({
    profileId: 'a',
    canSee: async () => true,
    send: (e) => seen.a.push(e),
  })
  const offB = server.realtime.add({
    profileId: 'b',
    canSee: async () => false,
    send: (e) => seen.b.push(e),
  })

  await server.realtime.publish({ type: 'activity.created', id: 'x1', scope: 'friends' })
  await tick()

  expect(seen.a).toHaveLength(1)
  expect(seen.a[0]!.id).toBe('x1')
  expect(seen.b).toHaveLength(0) // gated out

  offA()
  offB()
})

test('unsubscribe stops delivery; malformed payloads are ignored', async () => {
  const got: RealtimeEvent[] = []
  const off = server.realtime.add({
    profileId: 'a',
    canSee: async () => true,
    send: (e) => got.push(e),
  })

  off() // immediately unsubscribe
  await server.realtime.publish({ type: 'message.created', id: 'm1', squad_id: 's1' })
  await tick()
  expect(got).toHaveLength(0)

  // A non-JSON NOTIFY must not throw / crash the listener.
  await server.sql.notify('sq_events', 'not json{')
  await tick()
  expect(got).toHaveLength(0)
})
