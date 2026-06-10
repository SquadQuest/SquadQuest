import { afterAll, beforeAll, beforeEach, expect, test } from 'bun:test'
import Fastify, { type FastifyInstance } from 'fastify'

// Test env is configured by test/setup.ts (bun preload; see bunfig.toml).

const { app } = await import('../src/app.ts')

let server: FastifyInstance
let topicId: string

// Create a profile directly + mint an access token for it (skips OTP).
async function makeUser(phone: string) {
  const [row] = await server.sql<{ id: string }[]>`
    insert into profile (phone, first_name, claimed_at)
    values (${phone}, ${phone}, now()) returning id`
  const token = server.signAccessToken(row.id)
  return { id: row.id, token, auth: { authorization: `Bearer ${token}` } }
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
  await server.sql`truncate activity, friendship, profile cascade`
  const [t] = await server.sql<{ id: string }[]>`
    insert into topic (noun, verb, label) values ('Paddleboarding', 'Go', 'Go Paddleboarding')
    returning id`
  topicId = t.id
})

test('create idea (all_friends) appears for a friend, hidden from a stranger', async () => {
  const captain = await makeUser('+12150000001')
  const friend = await makeUser('+12150000002')
  const stranger = await makeUser('+12150000003')
  await befriend(captain.id, friend.id)

  const created = await server.inject({
    method: 'POST',
    url: '/v1/ideas',
    headers: captain.auth,
    payload: {
      activity_type_id: topicId,
      audience: { kind: 'all_friends' },
      allow_suggestions: true,
      time_options: ['Sat 7am', 'Sun 8am'],
    },
  })
  expect(created.statusCode).toBe(201)
  expect(created.json().state).toBe('idea')
  expect(created.json().time_options).toHaveLength(2)

  const forFriend = await server.inject({
    method: 'GET',
    url: '/v1/timeline/friends',
    headers: friend.auth,
  })
  expect(forFriend.json().items).toHaveLength(1)

  const forStranger = await server.inject({
    method: 'GET',
    url: '/v1/timeline/friends',
    headers: stranger.auth,
  })
  expect(forStranger.json().items).toHaveLength(0)
})

test('people-targeted idea is visible only to named recipients', async () => {
  const captain = await makeUser('+12150000010')
  const invited = await makeUser('+12150000011')
  const other = await makeUser('+12150000012')
  await befriend(captain.id, invited.id)
  await befriend(captain.id, other.id)

  await server.inject({
    method: 'POST',
    url: '/v1/ideas',
    headers: captain.auth,
    payload: {
      activity_type_id: topicId,
      audience: { kind: 'people', person_ids: [invited.id] },
    },
  })

  const a = await server.inject({ method: 'GET', url: '/v1/timeline/friends', headers: invited.auth })
  expect(a.json().items).toHaveLength(1)
  expect(a.json().items[0].audience).toEqual({ kind: 'people', summary: '1 person' })

  const b = await server.inject({ method: 'GET', url: '/v1/timeline/friends', headers: other.auth })
  expect(b.json().items).toHaveLength(0)
})

test('respond sets and clears your_response + counts', async () => {
  const captain = await makeUser('+12150000020')
  const friend = await makeUser('+12150000021')
  await befriend(captain.id, friend.id)
  const id = (
    await server.inject({
      method: 'POST',
      url: '/v1/ideas',
      headers: captain.auth,
      payload: { activity_type_id: topicId, audience: { kind: 'all_friends' } },
    })
  ).json().id

  const responded = await server.inject({
    method: 'PUT',
    url: `/v1/ideas/${id}/response`,
    headers: friend.auth,
    payload: { value: 'in' },
  })
  expect(responded.json().your_response).toBe('in')
  expect(responded.json().counts.in).toBe(1)

  const cleared = await server.inject({
    method: 'DELETE',
    url: `/v1/ideas/${id}/response`,
    headers: friend.auth,
  })
  expect(cleared.json().your_response).toBeNull()
  expect(cleared.json().counts.in).toBe(0)
})

test('suggest option is gated by allow_suggestions; voting toggles', async () => {
  const captain = await makeUser('+12150000030')
  const friend = await makeUser('+12150000031')
  await befriend(captain.id, friend.id)

  // allow_suggestions defaults false
  const closed = (
    await server.inject({
      method: 'POST',
      url: '/v1/ideas',
      headers: captain.auth,
      payload: { activity_type_id: topicId, audience: { kind: 'all_friends' } },
    })
  ).json()
  const denied = await server.inject({
    method: 'POST',
    url: `/v1/ideas/${closed.id}/options`,
    headers: friend.auth,
    payload: { kind: 'time', label: 'Mon 6pm' },
  })
  expect(denied.statusCode).toBe(403)
  expect(denied.json().error.code).toBe('suggestions_disabled')

  // open idea with an option → vote toggles
  const open = (
    await server.inject({
      method: 'POST',
      url: '/v1/ideas',
      headers: captain.auth,
      payload: {
        activity_type_id: topicId,
        audience: { kind: 'all_friends' },
        allow_suggestions: true,
        time_options: ['Sat 7am'],
      },
    })
  ).json()
  const optionId = open.time_options[0].id

  const voted = await server.inject({
    method: 'PUT',
    url: `/v1/ideas/${open.id}/votes`,
    headers: friend.auth,
    payload: { option_id: optionId, voted: true },
  })
  const opt = voted.json().time_options[0]
  expect(opt.votes).toBe(1)
  expect(opt.you_voted).toBe(true)
})

test('confirm is captain-only and promotes idea → activity', async () => {
  const captain = await makeUser('+12150000040')
  const friend = await makeUser('+12150000041')
  await befriend(captain.id, friend.id)
  const idea = (
    await server.inject({
      method: 'POST',
      url: '/v1/ideas',
      headers: captain.auth,
      payload: {
        activity_type_id: topicId,
        audience: { kind: 'all_friends' },
        time_options: ['Sun 2pm'],
        location_options: ['Willamette'],
      },
    })
  ).json()

  const notCaptain = await server.inject({
    method: 'POST',
    url: `/v1/ideas/${idea.id}/confirm`,
    headers: friend.auth,
    payload: {
      time_option_id: idea.time_options[0].id,
      location_option_id: idea.location_options[0].id,
    },
  })
  expect(notCaptain.statusCode).toBe(403)
  expect(notCaptain.json().error.code).toBe('not_captain')

  const confirmed = await server.inject({
    method: 'POST',
    url: `/v1/ideas/${idea.id}/confirm`,
    headers: captain.auth,
    payload: {
      time_option_id: idea.time_options[0].id,
      location_option_id: idea.location_options[0].id,
    },
  })
  expect(confirmed.statusCode).toBe(200)
  expect(confirmed.json().state).toBe('confirmed')
  expect(confirmed.json().confirmed_time).toBe('Sun 2pm')
  expect(confirmed.json().confirmed_location).toBe('Willamette')
})

test('friends timeline paginates over a cursor', async () => {
  const captain = await makeUser('+12150000050')
  const friend = await makeUser('+12150000051')
  await befriend(captain.id, friend.id)
  for (let i = 0; i < 3; i++) {
    await server.inject({
      method: 'POST',
      url: '/v1/ideas',
      headers: captain.auth,
      payload: { activity_type_id: topicId, audience: { kind: 'all_friends' } },
    })
  }

  const page1 = await server.inject({
    method: 'GET',
    url: '/v1/timeline/friends?limit=2',
    headers: friend.auth,
  })
  expect(page1.json().items).toHaveLength(2)
  expect(page1.json().next_cursor).toBeString()

  const page2 = await server.inject({
    method: 'GET',
    url: `/v1/timeline/friends?limit=2&before=${page1.json().next_cursor}`,
    headers: friend.auth,
  })
  expect(page2.json().items).toHaveLength(1)
  expect(page2.json().next_cursor).toBeNull()
})
