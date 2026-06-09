import type { FastifyPluginAsync } from 'fastify'

import healthRoutes from './health.ts'
import authRoutes from './auth.ts'
import meRoutes from './me.ts'
import friendsRoutes from './friends.ts'

// The /v1 contract surface. All client-facing endpoints register under here so
// the URL major version is the coarse contract boundary (see
// specs/api/conventions.md). New endpoints are additive; break by superseding.
const v1Routes: FastifyPluginAsync = async (fastify) => {
  await fastify.register(healthRoutes)
  await fastify.register(authRoutes)
  await fastify.register(meRoutes)
  await fastify.register(friendsRoutes)
}

export default v1Routes
