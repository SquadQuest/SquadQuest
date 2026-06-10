import type { FastifyPluginAsync } from 'fastify'
import { and, eq, or, inArray } from 'drizzle-orm'

import { profile, friendship } from '../../db/schema/index.ts'
import { FriendService } from '../../domain/friend/service.ts'
import { serializeFriend, serializeFriendRequest } from '../../contracts/friend.ts'

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

  // PUT /v1/friends/requests/:id — accept/decline an incoming request (requestee only).
  fastify.put<{ Params: { id: string }; Body: { accept: boolean } }>(
    '/friends/requests/:id',
    {
      preHandler: fastify.authenticate,
      schema: {
        body: {
          type: 'object',
          required: ['accept'],
          properties: { accept: { type: 'boolean' } },
        },
      },
    },
    async (request) => {
      const status = await friends.respond(
        request.profileId!,
        request.params.id,
        request.body.accept,
      )
      return { status }
    },
  )
}

export default friendsRoutes
