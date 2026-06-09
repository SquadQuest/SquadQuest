import type { FastifyPluginAsync } from 'fastify'
import fp from 'fastify-plugin'
import cors from '@fastify/cors'

import envPlugin from './plugins/env.ts'
import dbPlugin from './db/index.ts'
import clientVersionPlugin from './plugins/client-version.ts'
import authPlugin from './plugins/auth.ts'
import { ApiError, sendError } from './contracts/errors.ts'
import v1Routes from './routes/v1/index.ts'

export const app: FastifyPluginAsync = async (fastify) => {
  // Environment config must load first (validates + decorates fastify.config).
  await fastify.register(envPlugin)
  fastify.log.level = fastify.config.LOG_LEVEL

  // Database (decorates fastify.db + fastify.sql).
  await fastify.register(dbPlugin)

  // Conventions: client-build header + 426 floor, JWT auth (see
  // specs/api/conventions.md).
  await fastify.register(clientVersionPlugin)
  await fastify.register(authPlugin)

  await fastify.register(cors, {
    origin: fastify.config.NODE_ENV === 'production' ? false : true,
    credentials: true,
  })

  // Map thrown ApiErrors to the standard error envelope; everything else is a
  // generic 500 (logged) so internals never leak to the client.
  fastify.setErrorHandler((error, request, reply) => {
    if (error instanceof ApiError) {
      sendError(reply, error)
      return
    }
    // Fastify validation errors → 400 with a stable code.
    if ((error as { validation?: unknown }).validation) {
      reply.code(400).send({
        error: {
          code: 'bad_request',
          message: error instanceof Error ? error.message : 'Bad request',
        },
      })
      return
    }
    request.log.error(error)
    reply.code(500).send({
      error: { code: 'internal', message: 'Internal server error' },
    })
  })

  // The versioned API surface.
  await fastify.register(v1Routes, { prefix: '/v1' })

  fastify.addHook('onReady', async () => {
    fastify.log.info(`squadquest-server ready (${fastify.config.NODE_ENV})`)
    fastify.log.info('  GET /v1/health')
  })
}

export default fp(app, '5.x')
