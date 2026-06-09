import { afterAll, beforeAll, beforeEach, expect, test } from 'bun:test'
import Fastify, { type FastifyInstance } from 'fastify'

process.env.DATABASE_URL ??=
  'postgres://squadquest:squadquest@localhost:5532/squadquest_v2'
process.env.JWT_SECRET ??= 'test-secret-min-32-chars-xxxxxxxxxxxxx'
process.env.MIN_SUPPORTED_BUILD = '0'

const { app } = await import('../src/app.ts')

let server: FastifyInstance
let topicId: string

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
  await server.sql`truncate squad, squad_membership, activity, friendship, profile, topic cascade`
  const [t] = await server.sql<{ id: string }[]>`
    insert into topic (noun, verb, label) values ('Bike Ride', 'Go on a', 'Go on a Bike Ride')
    returning id`
  topicId = t.id
})

async function createSquad(auth: object, name: string, memberIds: string[] = []) {
  return server.inject({
    method: 'POST',
    url: '/v1/squads',
    headers: auth,
    payload: { name, member_ids: memberIds },
  })
}

test('create squad → creator is captain; members must be friends', async () => {
  const cap = await makeUser('+12150001000')
  const friend = await makeUser('+12150001001')
  const stranger = await makeUser('+12150001002')
  await befriend(cap.id, friend.id)

  // non-friend member rejected
  const bad = await createSquad(cap.auth, 'Riders', [stranger.id])
  expect(bad.statusCode).toBe(400)
  expect(bad.json().error.code).toBe('not_friends')

  const res = await createSquad(cap.auth, 'Riders', [friend.id])
  expect(res.statusCode).toBe(201)
  const detail = res.json()
  expect(detail.name).toBe('Riders')
  expect(detail.members).toHaveLength(2)
  const cation = detail.members.find((m: { id: string }) => m.id === cap.id)
  expect(cation.role).toBe('captain')

  // both members see it in their squad list
  for (const u of [cap, friend]) {
    const list = await server.inject({ method: 'GET', url: '/v1/squads', headers: u.auth })
    expect(list.json().items).toHaveLength(1)
    expect(list.json().items[0].member_count).toBe(2)
  }
  // stranger sees none, and is 404 on detail
  const strangerList = await server.inject({ method: 'GET', url: '/v1/squads', headers: stranger.auth })
  expect(strangerList.json().items).toHaveLength(0)
  const denied = await server.inject({ method: 'GET', url: `/v1/squads/${detail.id}`, headers: stranger.auth })
  expect(denied.statusCode).toBe(404)
})

test('captain adds a friend; non-captain cannot', async () => {
  const cap = await makeUser('+12150001010')
  const m1 = await makeUser('+12150001011')
  const m2 = await makeUser('+12150001012')
  await befriend(cap.id, m1.id)
  await befriend(cap.id, m2.id)
  const squadId = (await createSquad(cap.auth, 'Crew', [m1.id])).json().id

  // m1 (member, not captain) cannot add
  const denied = await server.inject({
    method: 'POST',
    url: `/v1/squads/${squadId}/members`,
    headers: m1.auth,
    payload: { profile_id: m2.id },
  })
  expect(denied.statusCode).toBe(403)
  expect(denied.json().error.code).toBe('not_captain')

  // captain adds m2
  const ok = await server.inject({
    method: 'POST',
    url: `/v1/squads/${squadId}/members`,
    headers: cap.auth,
    payload: { profile_id: m2.id },
  })
  expect(ok.statusCode).toBe(200)
  expect(ok.json().members).toHaveLength(3)
})

test('squad idea shows on the squad timeline, never on My Friends', async () => {
  const cap = await makeUser('+12150001020')
  const member = await makeUser('+12150001021')
  const outsider = await makeUser('+12150001022')
  await befriend(cap.id, member.id)
  await befriend(cap.id, outsider.id) // friend, but NOT in the squad
  const squadId = (await createSquad(cap.auth, 'Paddlers', [member.id])).json().id

  const created = await server.inject({
    method: 'POST',
    url: '/v1/ideas',
    headers: cap.auth,
    payload: {
      activity_type_id: topicId,
      scope: 'squad',
      squad_id: squadId,
      audience: { kind: 'all_friends' },
      time_options: ['Sat 9am'],
    },
  })
  expect(created.statusCode).toBe(201)
  expect(created.json().scope).toBe('squad')

  // member sees it on the squad timeline
  const memberFeed = await server.inject({
    method: 'GET',
    url: `/v1/squads/${squadId}/timeline`,
    headers: member.auth,
  })
  expect(memberFeed.json().items).toHaveLength(1)

  // it must NOT leak onto anyone's My Friends timeline (private-first)
  for (const u of [cap, member, outsider]) {
    const friends = await server.inject({ method: 'GET', url: '/v1/timeline/friends', headers: u.auth })
    expect(friends.json().items).toHaveLength(0)
  }

  // a friend who isn't a squad member can't read the squad timeline
  const denied = await server.inject({
    method: 'GET',
    url: `/v1/squads/${squadId}/timeline`,
    headers: outsider.auth,
  })
  expect(denied.statusCode).toBe(404)
})

test('non-member cannot create a squad-scoped idea', async () => {
  const cap = await makeUser('+12150001030')
  const outsider = await makeUser('+12150001031')
  const squadId = (await createSquad(cap.auth, 'Solo', [])).json().id

  const res = await server.inject({
    method: 'POST',
    url: '/v1/ideas',
    headers: outsider.auth,
    payload: {
      activity_type_id: topicId,
      scope: 'squad',
      squad_id: squadId,
      audience: { kind: 'all_friends' },
    },
  })
  expect(res.statusCode).toBe(403)
  expect(res.json().error.code).toBe('not_a_member')
})
