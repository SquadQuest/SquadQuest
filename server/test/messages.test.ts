import { afterAll, beforeAll, beforeEach, expect, test } from 'bun:test'
import Fastify, { type FastifyInstance } from 'fastify'

// Test env is configured by test/setup.ts (bun preload; see bunfig.toml).

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
  await server.sql`truncate message, squad, squad_membership, activity, friendship, community, community_event, profile, topic cascade`
  const [t] = await server.sql<{ id: string }[]>`
    insert into topic (noun, verb, label) values ('Bike Ride','Go on a','Go on a Bike Ride')
    returning id`
  topicId = t.id
})

async function seedCommunityEvent(): Promise<string> {
  const [c] = await server.sql<{ id: string }[]>`
    insert into community (name, tagline) values ('Wednesday Rides','ride bikes') returning id`
  const [e] = await server.sql<{ id: string }[]>`
    insert into community_event (community_id, title, time) values (${c.id}, 'Cherry Blossoms Ride', 'Wed 6:30pm')
    returning id`
  return e.id
}

function createSquad(auth: object, name: string, memberIds: string[] = []) {
  return server.inject({ method: 'POST', url: '/v1/squads', headers: auth, payload: { name, member_ids: memberIds } })
}
function createFriendsIdea(auth: object) {
  return server.inject({
    method: 'POST',
    url: '/v1/ideas',
    headers: auth,
    payload: { activity_type_id: topicId, audience: { kind: 'all_friends' } },
  })
}

test('squad message: member can post, non-member cannot; heterogeneous feed is type-tagged', async () => {
  const cap = await makeUser('+12150002000')
  const member = await makeUser('+12150002001')
  const outsider = await makeUser('+12150002002')
  await befriend(cap.id, member.id)
  const squadId = (await createSquad(cap.auth, 'Crew', [member.id])).json().id

  // a squad idea + a squad message
  await server.inject({
    method: 'POST',
    url: '/v1/ideas',
    headers: cap.auth,
    payload: { activity_type_id: topicId, scope: 'squad', squad_id: squadId, audience: { kind: 'all_friends' } },
  })
  const posted = await server.inject({
    method: 'POST',
    url: `/v1/squads/${squadId}/messages`,
    headers: member.auth,
    payload: { body: 'who is in for saturday?' },
  })
  expect(posted.statusCode).toBe(201)
  expect(posted.json().body).toBe('who is in for saturday?')

  // non-member cannot post
  const denied = await server.inject({
    method: 'POST',
    url: `/v1/squads/${squadId}/messages`,
    headers: outsider.auth,
    payload: { body: 'sneaking in' },
  })
  expect(denied.statusCode).toBe(404)

  // heterogeneous timeline: one activity + one message, each tagged
  const feed = await server.inject({ method: 'GET', url: `/v1/squads/${squadId}/timeline`, headers: cap.auth })
  const items = feed.json().items
  expect(items).toHaveLength(2)
  const types = items.map((i: { type: string }) => i.type).sort()
  expect(types).toEqual(['activity', 'message'])
  // newest first — the message was posted after the idea
  expect(items[0].type).toBe('message')
})

test('activity thread: audience can reply + read; thread_count increments; non-audience 404', async () => {
  const captain = await makeUser('+12150002010')
  const friend = await makeUser('+12150002011')
  const stranger = await makeUser('+12150002012')
  await befriend(captain.id, friend.id)
  const ideaId = (await createFriendsIdea(captain.auth)).json().id

  // friend (in audience) replies
  const reply = await server.inject({
    method: 'POST',
    url: `/v1/threads/activity/${ideaId}/messages`,
    headers: friend.auth,
    payload: { body: 'i am in!' },
  })
  expect(reply.statusCode).toBe(201)

  // captain reads the thread
  const thread = await server.inject({
    method: 'GET',
    url: `/v1/threads/activity/${ideaId}/messages`,
    headers: captain.auth,
  })
  expect(thread.json().items).toHaveLength(1)
  expect(thread.json().items[0].body).toBe('i am in!')

  // thread_count now shows on the activity (via the friends timeline)
  const feed = await server.inject({ method: 'GET', url: '/v1/timeline/friends', headers: captain.auth })
  const act = feed.json().items.find((a: { id: string }) => a.id === ideaId)
  expect(act.thread_count).toBe(1)

  // a stranger (not in audience) can neither read nor reply
  const denyRead = await server.inject({
    method: 'GET',
    url: `/v1/threads/activity/${ideaId}/messages`,
    headers: stranger.auth,
  })
  expect(denyRead.statusCode).toBe(404)
  const denyReply = await server.inject({
    method: 'POST',
    url: `/v1/threads/activity/${ideaId}/messages`,
    headers: stranger.auth,
    payload: { body: 'butting in' },
  })
  expect(denyReply.statusCode).toBe(404)
})

test('squad-message thread: members reply/read, non-members 404; free text never on My Friends', async () => {
  const cap = await makeUser('+12150002020')
  const member = await makeUser('+12150002021')
  const outsider = await makeUser('+12150002022')
  await befriend(cap.id, member.id)
  await befriend(cap.id, outsider.id) // friend but not in the squad
  const squadId = (await createSquad(cap.auth, 'Paddlers', [member.id])).json().id
  const msgId = (
    await server.inject({
      method: 'POST',
      url: `/v1/squads/${squadId}/messages`,
      headers: cap.auth,
      payload: { body: 'thread root' },
    })
  ).json().id

  const reply = await server.inject({
    method: 'POST',
    url: `/v1/threads/message/${msgId}/messages`,
    headers: member.auth,
    payload: { body: 'reply from member' },
  })
  expect(reply.statusCode).toBe(201)

  const denied = await server.inject({
    method: 'GET',
    url: `/v1/threads/message/${msgId}/messages`,
    headers: outsider.auth,
  })
  expect(denied.statusCode).toBe(404)

  // squad free text must never appear on any My Friends timeline
  for (const u of [cap, member, outsider]) {
    const friends = await server.inject({ method: 'GET', url: '/v1/timeline/friends', headers: u.auth })
    for (const item of friends.json().items) {
      expect(item.scope ?? 'friends').toBe('friends')
    }
  }
})

test('community_event thread: any user can reply/read (open community); thread_count surfaces; bad target 404s', async () => {
  const leader = await makeUser('+12150002030')
  const anyone = await makeUser('+12150002031')
  const eventId = await seedCommunityEvent()

  // anyone authenticated (communities are open) can reply
  const reply = await server.inject({
    method: 'POST',
    url: `/v1/threads/community_event/${eventId}/messages`,
    headers: anyone.auth,
    payload: { body: 'see you there!' },
  })
  expect(reply.statusCode).toBe(201)

  // and read it back
  const thread = await server.inject({
    method: 'GET',
    url: `/v1/threads/community_event/${eventId}/messages`,
    headers: leader.auth,
  })
  expect(thread.json().items).toHaveLength(1)
  expect(thread.json().items[0].body).toBe('see you there!')

  // thread_count is now reachable on the event card
  const [{ communityId }] = await server.sql<{ communityId: string }[]>`
    select community_id as "communityId" from community_event where id = ${eventId}`
  const events = await server.inject({
    method: 'GET',
    url: `/v1/communities/${communityId}/events`,
    headers: leader.auth,
  })
  const ev = events.json().items.find((e: { id: string }) => e.id === eventId)
  expect(ev.thread_count).toBe(1)

  // a thread on a nonexistent event 404s
  const missing = await server.inject({
    method: 'GET',
    url: '/v1/threads/community_event/00000000-0000-0000-0000-000000000000/messages',
    headers: leader.auth,
  })
  expect(missing.statusCode).toBe(404)
})
