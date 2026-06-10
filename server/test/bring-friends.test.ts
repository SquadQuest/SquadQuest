import { afterAll, beforeAll, beforeEach, expect, test } from 'bun:test'
import Fastify, { type FastifyInstance } from 'fastify'

// Test env is configured by test/setup.ts (bun preload; see bunfig.toml).

const { app } = await import('../src/app.ts')

let server: FastifyInstance
let topicId: string
let communityId: string
let eventId: string

async function makeUser(phone: string) {
  const [row] = await server.sql<{ id: string }[]>`
    insert into profile (phone, first_name, claimed_at)
    values (${phone}, ${phone}, now()) returning id`
  const token = server.signAccessToken(row.id)
  return { id: row.id, auth: { authorization: `Bearer ${token}` } }
}
async function befriend(a: string, b: string) {
  await server.sql`insert into friendship (requester, requestee, status) values (${a}, ${b}, 'accepted')`
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
  await server.sql`truncate community, community_event, community_event_rsvp, activity, friendship, profile, topic cascade`
  const [t] = await server.sql<{ id: string }[]>`
    insert into topic (noun, verb, label) values ('Bike Ride','Go on a','Go on a Bike Ride') returning id`
  topicId = t.id
  const [c] = await server.sql<{ id: string }[]>`insert into community (name) values ('Wednesday Night Rides') returning id`
  communityId = c.id
  const [e] = await server.sql<{ id: string }[]>`
    insert into community_event (community_id, title, time, location)
    values (${communityId}, ${'Cherry Blossoms Ride'}, ${'Wed 6:30pm'}, ${'Clark Park'}) returning id`
  eventId = e.id
})

test('brought-along idea is a friends-scoped activity carrying event_ref', async () => {
  const captain = await makeUser('+12150004000')
  const friend = await makeUser('+12150004001')
  await befriend(captain.id, friend.id)

  const created = await server.inject({
    method: 'POST',
    url: '/v1/ideas',
    headers: captain.auth,
    payload: {
      activity_type_id: topicId,
      audience: { kind: 'all_friends' },
      community_event_id: eventId,
    },
  })
  expect(created.statusCode).toBe(201)
  const body = created.json()
  expect(body.scope).toBe('friends')
  expect(body.event_ref).toBeTruthy()
  expect(body.event_ref.title).toBe('Cherry Blossoms Ride')
  expect(body.event_ref.community.name).toBe('Wednesday Night Rides')

  // it lands on the friend's My Friends timeline (a private envelope)…
  const feed = await server.inject({ method: 'GET', url: '/v1/timeline/friends', headers: friend.auth })
  const item = feed.json().items.find((a: { id: string }) => a.id === body.id)
  expect(item).toBeTruthy()
  expect(item.event_ref.id).toBe(eventId)

  // …and the public event itself is unchanged (community events are leader-owned only)
  const events = await server.inject({ method: 'GET', url: `/v1/communities/${communityId}/events`, headers: friend.auth })
  expect(events.json().items).toHaveLength(1)
  expect(events.json().items[0].id).toBe(eventId)
})

test('a brought-along "I\'m in" counts in the anonymous headcount, never the face-pile', async () => {
  const captain = await makeUser('+12150004010')
  const friend = await makeUser('+12150004011')
  await befriend(captain.id, friend.id)

  const idea = (
    await server.inject({
      method: 'POST',
      url: '/v1/ideas',
      headers: captain.auth,
      payload: { activity_type_id: topicId, audience: { kind: 'all_friends' }, community_event_id: eventId },
    })
  ).json()

  // before: nobody going
  let ev = (await server.inject({ method: 'GET', url: `/v1/communities/${communityId}/events`, headers: friend.auth })).json().items[0]
  expect(ev.going_count).toBe(0)

  // friend says "I'm in" on the brought-along idea (a friends-scoped action)
  const resp = await server.inject({
    method: 'PUT',
    url: `/v1/ideas/${idea.id}/response`,
    headers: friend.auth,
    payload: { value: 'in' },
  })
  expect(resp.statusCode).toBe(200)

  // → counted in the event's anonymous headcount, but NOT in the public face-pile
  ev = (await server.inject({ method: 'GET', url: `/v1/communities/${communityId}/events`, headers: captain.auth })).json().items[0]
  expect(ev.going_count).toBe(1)
  expect(ev.public_going).toHaveLength(0)
})
