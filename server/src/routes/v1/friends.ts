import type { FastifyPluginAsync } from 'fastify'
import { and, eq, or, inArray } from 'drizzle-orm'

import { profile, friendship } from '../../db/schema/index.ts'
import { FriendService } from '../../domain/friend/service.ts'
import { WantService } from '../../domain/want/service.ts'
import { serializeFriend, serializeFriendRequest } from '../../contracts/friend.ts'
import { serializeWants } from '../../contracts/want.ts'

// The accepted friend graph + double-opt-in connection requests.
// See specs/api/friends.md + specs/behaviors/friend-connections.md.
const friendsRoutes: FastifyPluginAsync = async (fastify) => {
  const friends = new FriendService(fastify.db)

  // GET /v1/friends — the caller's accepted friend graph (includes not-yet-claimed
  // friends, flagged on_v2:false). See specs/behaviors/v1-migration.md.
  fastify.get('/friends', { preHandler: fastify.authenticate }, async (request) => {
    const me = request.profileId!

    const edges = await fastify.db
      .select()
      .from(friendship)
      .where(
        and(
          eq(friendship.status, 'accepted'),
          or(eq(friendship.requester, me), eq(friendship.requestee, me)),
        ),
      )

    const friendIds = edges.map((e) => (e.requester === me ? e.requestee : e.requester))
    if (friendIds.length === 0) return { items: [] }

    const rows = await fastify.db
      .select()
      .from(profile)
      .where(inArray(profile.id, friendIds))

    return { items: rows.map(serializeFriend) }
  })

  // GET /v1/friends/requests — pending requests involving the caller, by direction.
  fastify.get(
    '/friends/requests',
    { preHandler: fastify.authenticate },
    async (request) => {
      const { incoming, outgoing } = await friends.listRequests(request.profileId!)
      return {
        incoming: incoming.map(serializeFriendRequest),
        outgoing: outgoing.map(serializeFriendRequest),
      }
    },
  )

  // POST /v1/friends/requests — send a request by phone. 201 requested | 200 accepted.
  fastify.post<{ Body: { phone: string } }>(
    '/friends/requests',
    {
      preHandler: fastify.authenticate,
      schema: {
        body: {
          type: 'object',
          required: ['phone'],
          properties: { phone: { type: 'string' } },
        },
      },
    },
    async (request, reply) => {
      const status = await friends.requestByPhone(request.profileId!, request.body.phone)
      reply.code(status === 'accepted' ? 200 : 201)
      return { status }
    },
  )

  // PUT /v1/friends/requests/:id — accept an incoming request (requestee only).
  // There is no decline; to make a request go away, ignore it (below).
  fastify.put<{ Params: { id: string }; Body: { accept: boolean } }>(
    '/friends/requests/:id',
    {
      preHandler: fastify.authenticate,
      schema: {
        body: {
          type: 'object',
          required: ['accept'],
          properties: { accept: { type: 'boolean', enum: [true] } },
        },
      },
    },
    async (request) => {
      const status = await friends.accept(request.profileId!, request.params.id)
      return { status }
    },
  )

  // POST /v1/friends/requests/:id/ignore — silent + recoverable (dismissal principle).
  fastify.post<{ Params: { id: string } }>(
    '/friends/requests/:id/ignore',
    { preHandler: fastify.authenticate },
    async (request) => {
      await friends.setIgnored(request.profileId!, request.params.id, true)
      return { status: 'requested', ignored: true }
    },
  )

  fastify.post<{ Params: { id: string } }>(
    '/friends/requests/:id/unignore',
    { preHandler: fastify.authenticate },
    async (request) => {
      await friends.setIgnored(request.profileId!, request.params.id, false)
      return { status: 'requested', ignored: false }
    },
  )

  // GET /v1/ignored — the caller's ignored incoming items, aggregated across types
  // (friend requests + want invites). See specs/screens/ignored.md.
  fastify.get('/ignored', { preHandler: fastify.authenticate }, async (request) => {
    const me = request.profileId!
    const [reqs, wantViews] = await Promise.all([
      friends.listIgnoredRequests(me),
      new WantService(fastify.db).listIgnored(me),
    ])
    const requestItems = reqs.map((r) => ({
      type: 'friend_request' as const,
      ...serializeFriendRequest(r),
    }))
    const wants = await serializeWants(fastify.db, me, wantViews)
    const wantItems = wants.map((w) => ({ type: 'want_invite' as const, ...w }))
    return { items: [...requestItems, ...wantItems] }
  })
}

export default friendsRoutes
