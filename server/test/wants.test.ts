import { afterAll, beforeAll, beforeEach, expect, test } from 'bun:test'
import Fastify, { type FastifyInstance } from 'fastify'

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
  await server.sql`truncate want, want_invite, activity, friendship, profile, topic cascade`
  const [t] = await server.sql<{ id: string }[]>`
    insert into topic (noun, verb, label) values ('Paddleboard','Go','Go Paddleboarding') returning id`
  topicId = t.id
})

function createWant(auth: object, body: object) {
  return server.inject({ method: 'POST', url: '/v1/wants', headers: auth, payload: body })
}

test('CRUD is owner-scoped: a non-owner cannot see or edit your want', async () => {
  const me = await makeUser('+12150004000')
  const other = await makeUser('+12150004001')

  const created = await createWant(me.auth, {
    activity_type_id: topicId,
    title: 'FDR lake',
    kind: 'one_shot',
  })
  expect(created.statusCode).toBe(201)
  const wantId = created.json().id
  expect(created.json().activity_type.label).toBe('Go Paddleboarding')

  // owner lists it
  const mine = await server.inject({ method: 'GET', url: '/v1/wants', headers: me.auth })
  expect(mine.json().items).toHaveLength(1)

  // a stranger sees none of their own, and can't patch/delete mine
  const theirs = await server.inject({ method: 'GET', url: '/v1/wants', headers: other.auth })
  expect(theirs.json().items).toHaveLength(0)
  const patch = await server.inject({
    method: 'PATCH',
    url: `/v1/wants/${wantId}`,
    headers: other.auth,
    payload: { title: 'hijack' },
  })
  expect(patch.statusCode).toBe(404)
})

test('invites require accepted friendship; invitee sees it and responds', async () => {
  const me = await makeUser('+12150004010')
  const friend = await makeUser('+12150004011')
  const stranger = await makeUser('+12150004012')
  await befriend(me.id, friend.id)

  // inviting a non-friend is rejected
  const badInvite = await createWant(me.auth, {
    activity_type_id: topicId,
    invitee_ids: [stranger.id],
  })
  expect(badInvite.statusCode).toBe(400)
  expect(badInvite.json().error.code).toBe('not_a_friend')

  // inviting a friend works
  const created = await createWant(me.auth, {
    activity_type_id: topicId,
    title: 'paddle soon',
    invitee_ids: [friend.id],
  })
  expect(created.statusCode).toBe(201)
  const wantId = created.json().id
  expect(created.json().invitees).toHaveLength(1)

  // the friend sees it in their invited list, with no response yet
  const invited = await server.inject({
    method: 'GET',
    url: '/v1/wants/invited',
    headers: friend.auth,
  })
  expect(invited.json().items).toHaveLength(1)
  expect(invited.json().items[0].your_response).toBeNull()

  // friend responds "in"
  const resp = await server.inject({
    method: 'PUT',
    url: `/v1/wants/${wantId}/response`,
    headers: friend.auth,
    payload: { value: 'in' },
  })
  expect(resp.statusCode).toBe(200)
  expect(resp.json().your_response).toBe('in')

  // owner sees the positive response on their want
  const mine = await server.inject({ method: 'GET', url: '/v1/wants', headers: me.auth })
  const inv = mine.json().items[0].invitees[0]
  expect(inv.response).toBe('in')
  expect(inv.profile.id).toBe(friend.id)
})

test('ignore removes the invite from the invitee list (silent + recoverable)', async () => {
  const me = await makeUser('+12150004020')
  const friend = await makeUser('+12150004021')
  await befriend(me.id, friend.id)
  const wantId = (
    await createWant(me.auth, { activity_type_id: topicId, invitee_ids: [friend.id] })
  ).json().id

  // friend ignores → leaves their invited list
  const ig = await server.inject({
    method: 'POST',
    url: `/v1/wants/${wantId}/ignore`,
    headers: friend.auth,
  })
  expect(ig.statusCode).toBe(204)
  const afterIgnore = await server.inject({
    method: 'GET',
    url: '/v1/wants/invited',
    headers: friend.auth,
  })
  expect(afterIgnore.json().items).toHaveLength(0)

  // owner is unaffected: still sees the invitee on their want (never told)
  const mine = await server.inject({ method: 'GET', url: '/v1/wants', headers: me.auth })
  expect(mine.json().items[0].invitees).toHaveLength(1)

  // un-ignore restores it
  await server.inject({
    method: 'POST',
    url: `/v1/wants/${wantId}/unignore`,
    headers: friend.auth,
  })
  const restored = await server.inject({
    method: 'GET',
    url: '/v1/wants/invited',
    headers: friend.auth,
  })
  expect(restored.json().items).toHaveLength(1)
})

test('promote spawns an idea with invitees as audience; one_shot archives', async () => {
  const me = await makeUser('+12150004030')
  const friend = await makeUser('+12150004031')
  await befriend(me.id, friend.id)
  const wantId = (
    await createWant(me.auth, {
      activity_type_id: topicId,
      title: 'paddle',
      kind: 'one_shot',
      invitee_ids: [friend.id],
    })
  ).json().id

  // promote with no audience → defaults to the invitees (people scope)
  const promoted = await server.inject({
    method: 'POST',
    url: `/v1/wants/${wantId}/promote`,
    headers: me.auth,
    payload: { time_options: ['Saturday AM'] },
  })
  expect(promoted.statusCode).toBe(201)
  const activityId = promoted.json().id

  // the new activity is back-linked to the want
  const [act] = await server.sql<{ from_want_id: string; audience_kind: string }[]>`
    select from_want_id, audience_kind from activity where id = ${activityId}`
  expect(act.from_want_id).toBe(wantId)
  expect(act.audience_kind).toBe('people')
  // friend is in the audience
  const [aud] = await server.sql<{ n: number }[]>`
    select count(*)::int as n from activity_audience where activity_id = ${activityId} and profile_id = ${friend.id}`
  expect(aud.n).toBe(1)

  // one_shot want is now archived (off the active list)
  const active = await server.inject({ method: 'GET', url: '/v1/wants', headers: me.auth })
  expect(active.json().items).toHaveLength(0)
  const all = await server.inject({
    method: 'GET',
    url: '/v1/wants?include_archived=true',
    headers: me.auth,
  })
  expect(all.json().items).toHaveLength(1)
  expect(all.json().items[0].archived_at).not.toBeNull()

  // promoting again → 409 (already archived)
  const again = await server.inject({
    method: 'POST',
    url: `/v1/wants/${wantId}/promote`,
    headers: me.auth,
    payload: {},
  })
  expect(again.statusCode).toBe(409)
})

test('ongoing want persists after promote and can spawn again', async () => {
  const me = await makeUser('+12150004040')
  const wantId = (
    await createWant(me.auth, { activity_type_id: topicId, kind: 'ongoing' })
  ).json().id

  const first = await server.inject({
    method: 'POST',
    url: `/v1/wants/${wantId}/promote`,
    headers: me.auth,
    payload: {},
  })
  expect(first.statusCode).toBe(201)

  // still active (not archived) → can promote a second time
  const active = await server.inject({ method: 'GET', url: '/v1/wants', headers: me.auth })
  expect(active.json().items).toHaveLength(1)
  const second = await server.inject({
    method: 'POST',
    url: `/v1/wants/${wantId}/promote`,
    headers: me.auth,
    payload: {},
  })
  expect(second.statusCode).toBe(201)
  expect(second.json().id).not.toBe(first.json().id)
})
