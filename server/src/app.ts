import type { FastifyPluginAsync } from 'fastify'
import fp from 'fastify-plugin'
import cors from '@fastify/cors'

import envPlugin from './plugins/env.ts'
import v1Routes from './routes/v1/index.ts'

export const app: FastifyPluginAsync = async (fastify) => {
  // Environment config must load first (validates + decorates fastify.config).
  await fastify.register(envPlugin)
  fastify.log.level = fastify.config.LOG_LEVEL

  await fastify.register(cors, {
    origin: fastify.config.NODE_ENV === 'production' ? false : true,
    credentials: true,
  })

  // The versioned API surface.
  await fastify.register(v1Routes, { prefix: '/v1' })

  fastify.addHook('onReady', async () => {
    fastify.log.info(`squadquest-server ready (${fastify.config.NODE_ENV})`)
    fastify.log.info('  GET /v1/health')
  })
}

export default fp(app, '5.x')
