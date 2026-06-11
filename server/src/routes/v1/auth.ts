import type { FastifyPluginAsync } from 'fastify'
import { eq } from 'drizzle-orm'

import { profile } from '../../db/schema/index.ts'
import { serializeProfile } from '../../contracts/profile.ts'
import { AuthService } from '../../domain/auth/service.ts'
import {
  ConsoleOtpProvider,
  TwilioVerifyOtpProvider,
  type OtpProvider,
} from '../../domain/auth/otp-provider.ts'

// POST /v1/auth/otp/{request,verify}, /refresh, /logout. See specs/api/auth.md.
const authRoutes: FastifyPluginAsync = async (fastify) => {
  const { TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_VERIFY_SERVICE_SID } =
    fastify.config

  // Twilio Verify in prod (all three secrets present); the dev console provider
  // (self-managed codes, logged) otherwise — so local dev + tests need no Twilio.
  const otp: OtpProvider =
    TWILIO_ACCOUNT_SID && TWILIO_AUTH_TOKEN && TWILIO_VERIFY_SERVICE_SID
      ? new TwilioVerifyOtpProvider(
          {
            accountSid: TWILIO_ACCOUNT_SID,
            authToken: TWILIO_AUTH_TOKEN,
            serviceSid: TWILIO_VERIFY_SERVICE_SID,
          },
          fastify.log,
        )
      : new ConsoleOtpProvider(fastify.db, fastify.log)

  if (otp instanceof ConsoleOtpProvider) {
    fastify.log.warn('OTP: using dev ConsoleOtpProvider (no Twilio config)')
  }

  const auth = new AuthService(fastify.db, otp, (profileId) =>
    fastify.signAccessToken(profileId),
  )

  fastify.post<{ Body: { phone: string } }>(
    '/auth/otp/request',
    {
      schema: {
        body: {
          type: 'object',
          required: ['phone'],
          properties: { phone: { type: 'string' } },
        },
      },
    },
    async (request) => {
      const { expiresIn } = await auth.requestOtp(request.body.phone)
      return { expires_in: expiresIn }
    },
  )

  fastify.post<{ Body: { phone: string; code: string } }>(
    '/auth/otp/verify',
    {
      schema: {
        body: {
          type: 'object',
          required: ['phone', 'code'],
          properties: { phone: { type: 'string' }, code: { type: 'string' } },
        },
      },
    },
    async (request) => {
      const result = await auth.verifyOtp(request.body.phone, request.body.code)
      const [row] = await fastify.db
        .select()
        .from(profile)
        .where(eq(profile.id, result.profileId))
      return {
        access_token: result.accessToken,
        refresh_token: result.refreshToken,
        profile: serializeProfile(row!),
        claimed_v1: result.claimedV1,
      }
    },
  )

  fastify.post<{ Body: { refresh_token: string } }>(
    '/auth/refresh',
    {
      schema: {
        body: {
          type: 'object',
          required: ['refresh_token'],
          properties: { refresh_token: { type: 'string' } },
        },
      },
    },
    async (request) => {
      const t = await auth.refresh(request.body.refresh_token)
      return { access_token: t.accessToken, refresh_token: t.refreshToken }
    },
  )

  fastify.post<{ Body: { refresh_token: string } }>(
    '/auth/logout',
    {
      schema: {
        body: {
          type: 'object',
          required: ['refresh_token'],
          properties: { refresh_token: { type: 'string' } },
        },
      },
    },
    async (request, reply) => {
      await auth.logout(request.body.refresh_token)
      reply.code(204)
    },
  )
}

export default authRoutes
