import { afterAll, beforeAll, beforeEach, expect, test } from 'bun:test'
import Fastify, { type FastifyInstance } from 'fastify'

// Test env is configured by test/setup.ts (bun preload; see bunfig.toml).

const { app } = await import('../src/app.ts')

let server: FastifyInstance

async function makeUser(phone: string) {
  const [row] = await server.sql<{ id: string }[]>`
    insert into profile (phone, first_name, claimed_at)
    values (${phone}, ${phone}, now()) returning id`
  const token = server.signAccessToken(row.id)
  return { id: row.id, auth: { authorization: `Bearer ${token}` } }
}

async function seedCommunity(name: string) {
  const [c] = await server.sql<{ id: string }[]>`
    insert into community (name, tagline) values (${name}, ${'ride bikes'}) returning id`
  return c.id
}
async function seedEvent(communityId: string, title: string) {
  const [e] = await server.sql<{ id: string }[]>`
    insert into community_event (community_id, title, time, recurrence, location)
    values (${communityId}, ${title}, ${'Wed 6:30pm'}, ${'Every Wed'}, ${'Clark Park'})
    returning id`
  return e.id
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
  await server.sql`truncate community, community_membership, community_event, community_event_rsvp, profile cascade`
})

test('discover + follow toggles follower_count and you_follow', async () => {
  const user = await makeUser('+12150003000')
  const cid = await seedCommunity('Wednesday Night Rides')
  await seedCommunity('Black Squirrel Club')

  let res = await server.inject({ method: 'GET', url: '/v1/communities', headers: user.auth })
  expect(res.json().items).toHaveLength(2)
  expect(res.json().items.every((c: { you_follow: boolean }) => !c.you_follow)).toBe(true)

  const followed = await server.inject({
    method: 'PUT',
    url: `/v1/communities/${cid}/follow`,
    headers: user.auth,
    payload: { follow: true },
  })
  expect(followed.json()).toEqual({ you_follow: true, follower_count: 1 })

  res = await server.inject({ method: 'GET', url: '/v1/communities', headers: user.auth })
  const c = res.json().items.find((x: { id: string }) => x.id === cid)
  expect(c.you_follow).toBe(true)
  expect(c.follower_count).toBe(1)

  const unfollowed = await server.inject({
    method: 'PUT',
    url: `/v1/communities/${cid}/follow`,
    headers: user.auth,
    payload: { follow: false },
  })
  expect(unfollowed.json()).toEqual({ you_follow: false, follower_count: 0 })
})

test('RSVP visibility gradient: going is anonymous, public is explicit and implies going', async () => {
  const user = await makeUser('+12150003010')
  const cid = await seedCommunity('Wednesday Night Rides')
  const eid = await seedEvent(cid, 'Cherry Blossoms Ride')

  // initial: not going, empty face-pile
  let ev = (await server.inject({ method: 'GET', url: `/v1/communities/${cid}/events`, headers: user.auth })).json().items[0]
  expect(ev.going_count).toBe(0)
  expect(ev.your_rsvp).toEqual({ going: false, public: false })

  // going only → anonymous count, NOT in face-pile
  ev = (await server.inject({
    method: 'PUT',
    url: `/v1/community-events/${eid}/rsvp`,
    headers: user.auth,
    payload: { going: true, public: false },
  })).json()
  expect(ev.going_count).toBe(1)
  expect(ev.public_going).toHaveLength(0)
  expect(ev.your_rsvp).toEqual({ going: true, public: false })

  // show name → joins face-pile (still one attendee)
  ev = (await server.inject({
    method: 'PUT',
    url: `/v1/community-events/${eid}/rsvp`,
    headers: user.auth,
    payload: { going: true, public: true },
  })).json()
  expect(ev.going_count).toBe(1)
  expect(ev.public_going).toHaveLength(1)
  expect(ev.public_going[0].id).toBe(user.id)

  // public alone implies going
  await server.inject({
    method: 'PUT',
    url: `/v1/community-events/${eid}/rsvp`,
    headers: user.auth,
    payload: { going: false, public: false },
  })
  ev = (await server.inject({
    method: 'PUT',
    url: `/v1/community-events/${eid}/rsvp`,
    headers: user.auth,
    payload: { public: true },
  })).json()
  expect(ev.your_rsvp).toEqual({ going: true, public: true })

  // going:false clears both
  ev = (await server.inject({
    method: 'PUT',
    url: `/v1/community-events/${eid}/rsvp`,
    headers: user.auth,
    payload: { going: false },
  })).json()
  expect(ev.going_count).toBe(0)
  expect(ev.your_rsvp).toEqual({ going: false, public: false })
})
