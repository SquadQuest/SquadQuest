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
    // Twilio Verify (SMS OTP). When all three are present the auth routes use
    // Twilio; otherwise they fall back to the dev ConsoleOtpProvider. Optional so
    // local dev / tests need no Twilio account.
    TWILIO_ACCOUNT_SID: { type: 'string', default: '' },
    TWILIO_AUTH_TOKEN: { type: 'string', default: '' },
    TWILIO_VERIFY_SERVICE_SID: { type: 'string', default: '' },
    // GCS bucket for user media (signed-URL uploads, public-key reads). Empty
    // disables the uploads endpoint (local dev without GCS creds).
    MEDIA_BUCKET: { type: 'string', default: '' },
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
      TWILIO_ACCOUNT_SID: string
      TWILIO_AUTH_TOKEN: string
      TWILIO_VERIFY_SERVICE_SID: string
      MEDIA_BUCKET: string
    }
  }
}

export default fp(async (fastify) => {
  await fastify.register(fastifyEnv, { schema, dotenv: true })
})
