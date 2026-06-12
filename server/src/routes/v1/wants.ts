import type { FastifyPluginAsync } from 'fastify'
import { eq } from 'drizzle-orm'

import { activity } from '../../db/schema/index.ts'
import { WantService } from '../../domain/want/service.ts'
import { serializeWant, serializeWants } from '../../contracts/want.ts'
import { serializeActivity } from '../../contracts/activity.ts'

// Wants: a shared backlog of pre-activities (specs/api/wants.md). All authed.
interface CreateWantBody {
  activity_type_id: string
  title?: string
  location?: string
  notes?: string
  kind?: 'one_shot' | 'ongoing'
  invitee_ids?: string[]
}
interface PromoteBody {
  scope?: 'friends' | 'squad'
  squad_id?: string
  audience?: { kind: 'all_friends' | 'people'; person_ids?: string[] }
  allow_suggestions?: boolean
  time_options?: string[]
  location_options?: string[]
  community_event_id?: string
}

const wantRoutes: FastifyPluginAsync = async (fastify) => {
  const svc = new WantService(fastify.db)

  const RESPONSE_ENUM = { type: 'string', enum: ['in', 'interested', 'next_time'] } as const

  fastify.get('/wants', { preHandler: fastify.authenticate }, async (request) => {
    const includeArchived =
      (request.query as { include_archived?: string }).include_archived === 'true'
    const views = await svc.listOwn(request.profileId!, includeArchived)
    return { items: await serializeWants(fastify.db, request.profileId!, views) }
  })

  fastify.get('/wants/invited', { preHandler: fastify.authenticate }, async (request) => {
    const views = await svc.listInvited(request.profileId!)
    return { items: await serializeWants(fastify.db, request.profileId!, views) }
  })

  fastify.post<{ Body: CreateWantBody }>(
    '/wants',
    { preHandler: fastify.authenticate },
    async (request, reply) => {
      const b = request.body
      const view = await svc.create(request.profileId!, {
        activityTypeId: b.activity_type_id,
        title: b.title,
        location: b.location,
        notes: b.notes,
        kind: b.kind,
        inviteeIds: b.invitee_ids,
      })
      reply.code(201)
      return serializeWant(fastify.db, request.profileId!, view)
    },
  )

  fastify.patch<{ Params: { id: string }; Body: Partial<CreateWantBody> }>(
    '/wants/:id',
    { preHandler: fastify.authenticate },
    async (request) => {
      const b = request.body
      const view = await svc.update(request.profileId!, request.params.id, {
        activityTypeId: b.activity_type_id,
        title: b.title,
        location: b.location,
        notes: b.notes,
        kind: b.kind,
      })
      return serializeWant(fastify.db, request.profileId!, view)
    },
  )

  fastify.delete<{ Params: { id: string } }>(
    '/wants/:id',
    { preHandler: fastify.authenticate },
    async (request, reply) => {
      await svc.remove(request.profileId!, request.params.id)
      reply.code(204)
    },
  )

  // Invites (owner)
  fastify.post<{ Params: { id: string }; Body: { profile_ids: string[] } }>(
    '/wants/:id/invites',
    { preHandler: fastify.authenticate },
    async (request) => {
      const view = await svc.invite(
        request.profileId!,
        request.params.id,
        request.body.profile_ids ?? [],
      )
      return serializeWant(fastify.db, request.profileId!, view)
    },
  )

  fastify.delete<{ Params: { id: string; profileId: string } }>(
    '/wants/:id/invites/:profileId',
    { preHandler: fastify.authenticate },
    async (request) => {
      const view = await svc.uninvite(
        request.profileId!,
        request.params.id,
        request.params.profileId,
      )
      return serializeWant(fastify.db, request.profileId!, view)
    },
  )

  // Response (invitee)
  fastify.put<{ Params: { id: string }; Body: { value: 'in' | 'interested' | 'next_time' } }>(
    '/wants/:id/response',
    {
      preHandler: fastify.authenticate,
      schema: {
        body: { type: 'object', required: ['value'], properties: { value: RESPONSE_ENUM } },
      },
    },
    async (request) => {
      const view = await svc.respond(request.profileId!, request.params.id, request.body.value)
      return serializeWant(fastify.db, request.profileId!, view)
    },
  )

  fastify.delete<{ Params: { id: string } }>(
    '/wants/:id/response',
    { preHandler: fastify.authenticate },
    async (request) => {
      const view = await svc.clearResponse(request.profileId!, request.params.id)
      return serializeWant(fastify.db, request.profileId!, view)
    },
  )

  // Ignore / un-ignore (invitee) — silent + recoverable (dismissal principle).
  fastify.post<{ Params: { id: string } }>(
    '/wants/:id/ignore',
    { preHandler: fastify.authenticate },
    async (request, reply) => {
      await svc.setIgnored(request.profileId!, request.params.id, true)
      reply.code(204)
    },
  )

  fastify.post<{ Params: { id: string } }>(
    '/wants/:id/unignore',
    { preHandler: fastify.authenticate },
    async (request, reply) => {
      await svc.setIgnored(request.profileId!, request.params.id, false)
      reply.code(204)
    },
  )

  // Promote = spawn an idea (owner). Returns the new serialized activity.
  fastify.post<{ Params: { id: string }; Body: PromoteBody }>(
    '/wants/:id/promote',
    { preHandler: fastify.authenticate },
    async (request, reply) => {
      const b = request.body ?? {}
      const activityId = await svc.promote(request.profileId!, request.params.id, {
        scope: b.scope,
        squadId: b.squad_id,
        audience: b.audience
          ? { kind: b.audience.kind, personIds: b.audience.person_ids }
          : undefined,
        allowSuggestions: b.allow_suggestions,
        timeOptions: b.time_options,
        locationOptions: b.location_options,
        communityEventId: b.community_event_id,
      })
      const [row] = await fastify.db.select().from(activity).where(eq(activity.id, activityId))
      reply.code(201)
      return serializeActivity(fastify.db, request.profileId!, row!)
    },
  )
}

export default wantRoutes
