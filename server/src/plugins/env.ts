import fp from 'fastify-plugin'
import fastifyEnv from '@fastify/env'

const schema = {
  type: 'object',
  required: ['DATABASE_URL', 'JWT_SECRET'],
  properties: {
    PORT: { type: 'number', default: 4000 },
    HOST: { type: 'string', default: '0.0.0.0' },
    NODE_ENV: {
      type: 'string',
      enum: ['development', 'production', 'test'],
      default: 'development',
    },
    LOG_LEVEL: {
      type: 'string',
      enum: ['fatal', 'error', 'warn', 'info', 'debug', 'trace'],
      default: 'info',
    },
    DATABASE_URL: { type: 'string' },
    JWT_SECRET: { type: 'string', minLength: 32 },
    // Lowest client build allowed; requests below it get 426 (see
    // specs/api/conventions.md). 0 = no floor.
    MIN_SUPPORTED_BUILD: { type: 'number', default: 0 },
  },
}

declare module 'fastify' {
  interface FastifyInstance {
    config: {
      PORT: number
      HOST: string
      NODE_ENV: 'development' | 'production' | 'test'
      LOG_LEVEL: 'fatal' | 'error' | 'warn' | 'info' | 'debug' | 'trace'
      DATABASE_URL: string
      JWT_SECRET: string
      MIN_SUPPORTED_BUILD: number
    }
  }
}

export default fp(async (fastify) => {
  await fastify.register(fastifyEnv, { schema, dotenv: true })
})
