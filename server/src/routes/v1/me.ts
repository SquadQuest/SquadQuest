import type { FastifyPluginAsync } from 'fastify'
import { eq } from 'drizzle-orm'

import { profile } from '../../db/schema/index.ts'
import { serializeProfile } from '../../contracts/profile.ts'
import { errors } from '../../contracts/errors.ts'

// The authenticated user's own profile. See specs/api/profile.md.
const meRoutes: FastifyPluginAsync = async (fastify) => {
  // GET /v1/me — the caller's profile (null first_name = needs onboarding).
  fastify.get('/me', { preHandler: fastify.authenticate }, async (request) => {
    const [row] = await fastify.db
      .select()
      .from(profile)
      .where(eq(profile.id, request.profileId!))
    if (!row) throw errors.unauthorized()
    return serializeProfile(row)
  })

  // PATCH /v1/me — update own profile (onboarding profile-setup + later edits).
  // Only provided fields change; first_name must be non-empty when present.
  fastify.patch<{ Body: { first_name?: string; last_name?: string; photo?: string } }>(
    '/me',
    {
      preHandler: fastify.authenticate,
      schema: {
        body: {
          type: 'object',
          properties: {
            first_name: { type: 'string' },
            last_name: { type: 'string' },
            photo: { type: 'string' },
          },
        },
      },
    },
    async (request) => {
      const { first_name, last_name, photo } = request.body
      const updates: { firstName?: string; lastName?: string | null; photo?: string | null } = {}

      if (first_name !== undefined) {
        if (first_name.trim() === '') {
          throw errors.badRequest('first_name_required', 'first_name must be non-empty')
        }
        updates.firstName = first_name.trim()
      }
      if (last_name !== undefined) {
        updates.lastName = last_name.trim() === '' ? null : last_name.trim()
      }
      if (photo !== undefined) {
        updates.photo = photo.trim() === '' ? null : photo.trim()
      }

      const [row] = await fastify.db
        .update(profile)
        .set(updates)
        .where(eq(profile.id, request.profileId!))
        .returning()
      if (!row) throw errors.unauthorized()
      return serializeProfile(row)
    },
  )
}

export default meRoutes
