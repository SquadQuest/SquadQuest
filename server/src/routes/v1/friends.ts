import type { FastifyPluginAsync } from 'fastify'
import { and, eq, or, inArray } from 'drizzle-orm'

import { profile, friendship } from '../../db/schema/index.ts'
import { serializeFriend } from '../../contracts/friend.ts'

// GET /v1/friends — the authenticated user's accepted friend graph (includes
// not-yet-claimed friends, flagged on_v2:false). See specs/behaviors/v1-migration.md.
const friendsRoutes: FastifyPluginAsync = async (fastify) => {
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
}

export default friendsRoutes
