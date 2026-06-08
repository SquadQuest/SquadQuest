import type { FastifyPluginAsync } from 'fastify'

const healthRoutes: FastifyPluginAsync = async (fastify) => {
  fastify.get('/health', async () => {
    return {
      status: 'ok',
      service: 'squadquest-server',
      environment: fastify.config.NODE_ENV,
      timestamp: new Date().toISOString(),
    }
  })
}

export default healthRoutes
