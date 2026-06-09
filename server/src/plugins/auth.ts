import fp from 'fastify-plugin'
import type { FastifyRequest } from 'fastify'
import jwt from 'jsonwebtoken'

import { errors } from '../contracts/errors.ts'

const ACCESS_TTL = '15m'

interface AccessClaims {
  sub: string // profile id
}

declare module 'fastify' {
  interface FastifyInstance {
    // Signs a short-lived access token for a profile.
    signAccessToken(profileId: string): string
    // preHandler that requires a valid bearer token; sets request.profileId.
    authenticate(request: FastifyRequest): Promise<void>
  }
  interface FastifyRequest {
    profileId: string | null
  }
}

function extractBearer(request: FastifyRequest): string | null {
  const header = request.headers.authorization
  if (!header) return null
  const [scheme, token] = header.split(' ')
  if (scheme?.toLowerCase() !== 'bearer' || !token) return null
  return token
}

// JWT bearer auth (access tokens). Refresh tokens are opaque + DB-backed (see
// domain/auth). See specs/api/conventions.md (Auth).
export default fp(async (fastify) => {
  const secret = fastify.config.JWT_SECRET

  fastify.decorate('signAccessToken', (profileId: string) =>
    jwt.sign({ sub: profileId } satisfies AccessClaims, secret, {
      expiresIn: ACCESS_TTL,
    }),
  )

  fastify.decorateRequest('profileId', null)

  fastify.decorate('authenticate', async (request: FastifyRequest) => {
    const token = extractBearer(request)
    if (!token) throw errors.unauthorized()
    try {
      const claims = jwt.verify(token, secret) as AccessClaims
      request.profileId = claims.sub
    } catch {
      throw errors.unauthorized('Invalid or expired token')
    }
  })
})
