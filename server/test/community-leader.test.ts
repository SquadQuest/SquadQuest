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
  await server.sql`truncate community, community_membership, community_event, community_event_rsvp, profile cascade`
})

test('creating a community makes you its leader; others see your_role null', async () => {
  const leader = await makeUser('+12150010000')
  const other = await makeUser('+12150010001')

  const created = await server.inject({
    method: 'POST',
    url: '/v1/communities',
    headers: leader.auth,
    payload: { name: 'Wednesday Night Rides', tagline: 'ride bikes', icon: '🚲' },
  })
  expect(created.statusCode).toBe(201)
  expect(created.json()).toMatchObject({
    name: 'Wednesday Night Rides',
    you_follow: true,
    your_role: 'leader',
    follower_count: 1,
  })
  const cid = created.json().id

  // The leader sees their role in discover; a stranger sees null.
  const leaderList = (
    await server.inject({ method: 'GET', url: '/v1/communities', headers: leader.auth })
  ).json().items;
  expect(leaderList.find((c: { id: string }) => c.id === cid).your_role).toBe('leader')

  const otherList = (
    await server.inject({ method: 'GET', url: '/v1/communities', headers: other.auth })
  ).json().items;
  expect(otherList.find((c: { id: string }) => c.id === cid).your_role).toBeNull()
})

test('leader can edit the community; a non-leader gets 403', async () => {
  const leader = await makeUser('+12150010010')
  const other = await makeUser('+12150010011')
  const cid = (
    await server.inject({
      method: 'POST',
      url: '/v1/communities',
      headers: leader.auth,
      payload: { name: 'Trail Club' },
    })
  ).json().id

  const edited = await server.inject({
    method: 'PATCH',
    url: `/v1/communities/${cid}`,
    headers: leader.auth,
    payload: { tagline: 'trail running + social' },
  })
  expect(edited.statusCode).toBe(200)
  expect(edited.json().tagline).toBe('trail running + social')

  const forbidden = await server.inject({
    method: 'PATCH',
    url: `/v1/communities/${cid}`,
    headers: other.auth,
    payload: { name: 'Hijacked' },
  })
  expect(forbidden.statusCode).toBe(403)
  expect(forbidden.json().error.code).toBe('forbidden')
})

test('leader posts an event; it appears on the timeline; non-leader cannot post', async () => {
  const leader = await makeUser('+12150010020')
  const other = await makeUser('+12150010021')
  const cid = (
    await server.inject({
      method: 'POST',
      url: '/v1/communities',
      headers: leader.auth,
      payload: { name: 'River Flow' },
    })
  ).json().id

  const posted = await server.inject({
    method: 'POST',
    url: `/v1/communities/${cid}/events`,
    headers: leader.auth,
    payload: {
      title: 'Morning Paddle',
      time: 'Sun · 9am',
      recurrence: 'Every Sun',
      location: "Bartram's Dock",
    },
  })
  expect(posted.statusCode).toBe(201)
  expect(posted.json()).toMatchObject({
    title: 'Morning Paddle',
    recurrence: 'Every Sun',
    going_count: 0,
  })

  const events = (
    await server.inject({
      method: 'GET',
      url: `/v1/communities/${cid}/events`,
      headers: other.auth,
    })
  ).json().items
  expect(events).toHaveLength(1)
  expect(events[0].title).toBe('Morning Paddle')

  // A follower (non-leader) cannot post.
  const forbidden = await server.inject({
    method: 'POST',
    url: `/v1/communities/${cid}/events`,
    headers: other.auth,
    payload: { title: 'Sneaky Event' },
  })
  expect(forbidden.statusCode).toBe(403)
})

test('leader edits + deletes an event (cascading RSVPs); non-leader is blocked', async () => {
  const leader = await makeUser('+12150010030')
  const other = await makeUser('+12150010031')
  const cid = (
    await server.inject({
      method: 'POST',
      url: '/v1/communities',
      headers: leader.auth,
      payload: { name: 'Night Rides' },
    })
  ).json().id
  const eid = (
    await server.inject({
      method: 'POST',
      url: `/v1/communities/${cid}/events`,
      headers: leader.auth,
      payload: { title: 'Cherry Blossoms Ride', time: 'Wed · 6:30pm' },
    })
  ).json().id

  // Someone RSVPs.
  await server.inject({
    method: 'PUT',
    url: `/v1/community-events/${eid}/rsvp`,
    headers: other.auth,
    payload: { going: true },
  })

  // Edit (leader).
  const edited = await server.inject({
    method: 'PATCH',
    url: `/v1/community-events/${eid}`,
    headers: leader.auth,
    payload: { title: 'Cherry Blossoms Ride (rescheduled)' },
  })
  expect(edited.statusCode).toBe(200)
  expect(edited.json().title).toBe('Cherry Blossoms Ride (rescheduled)')

  // Non-leader cannot edit or delete.
  expect(
    (
      await server.inject({
        method: 'PATCH',
        url: `/v1/community-events/${eid}`,
        headers: other.auth,
        payload: { title: 'nope' },
      })
    ).statusCode,
  ).toBe(403)
  expect(
    (
      await server.inject({
        method: 'DELETE',
        url: `/v1/community-events/${eid}`,
        headers: other.auth,
      })
    ).statusCode,
  ).toBe(403)

  // Delete (leader) → 204; event + its RSVPs gone.
  const deleted = await server.inject({
    method: 'DELETE',
    url: `/v1/community-events/${eid}`,
    headers: leader.auth,
  })
  expect(deleted.statusCode).toBe(204)
  const events = (
    await server.inject({
      method: 'GET',
      url: `/v1/communities/${cid}/events`,
      headers: leader.auth,
    })
  ).json().items
  expect(events).toHaveLength(0)
  const [{ count }] = await server.sql<{ count: number }[]>`
    select count(*)::int as count from community_event_rsvp where event_id = ${eid}`
  expect(count).toBe(0)
})

test('a leader unfollowing keeps their leadership (no-op)', async () => {
  const leader = await makeUser('+12150010040')
  const cid = (
    await server.inject({
      method: 'POST',
      url: '/v1/communities',
      headers: leader.auth,
      payload: { name: 'Persistent Club' },
    })
  ).json().id

  const unfollow = await server.inject({
    method: 'PUT',
    url: `/v1/communities/${cid}/follow`,
    headers: leader.auth,
    payload: { follow: false },
  })
  // Still a member (leadership implies following).
  expect(unfollow.json()).toEqual({ you_follow: true, follower_count: 1 })

  // Can still post events.
  expect(
    (
      await server.inject({
        method: 'POST',
        url: `/v1/communities/${cid}/events`,
        headers: leader.auth,
        payload: { title: 'Still leading' },
      })
    ).statusCode,
  ).toBe(201)
})
