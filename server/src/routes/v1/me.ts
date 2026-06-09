import type { FastifyPluginAsync } from 'fastify'
import { eq } from 'drizzle-orm'

import { profile } from '../../db/schema/index.ts'
import { serializeProfile } from '../../contracts/profile.ts'
import { errors } from '../../contracts/errors.ts'

// GET /v1/me — the authenticated user's profile.
const meRoutes: FastifyPluginAsync = async (fastify) => {
  fastify.get('/me', { preHandler: fastify.authenticate }, async (request) => {
    const [row] = await fastify.db
      .select()
      .from(profile)
      .where(eq(profile.id, request.profileId!))
    if (!row) throw errors.unauthorized()
    return serializeProfile(row)
  })
}

export default meRoutes
