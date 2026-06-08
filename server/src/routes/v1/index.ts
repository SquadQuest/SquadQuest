import type { FastifyPluginAsync } from 'fastify'

import healthRoutes from './health.ts'

// The /v1 contract surface. All client-facing endpoints register under here so
// the URL major version is the coarse contract boundary (see
// specs/api/conventions.md). New endpoints are additive; break by superseding.
const v1Routes: FastifyPluginAsync = async (fastify) => {
  await fastify.register(healthRoutes)
}

export default v1Routes
