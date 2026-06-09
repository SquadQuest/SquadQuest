import type { FastifyPluginAsync } from 'fastify'
import { eq } from 'drizzle-orm'

import { activity } from '../../db/schema/index.ts'
import { ActivityService } from '../../domain/activity/service.ts'
import { serializeActivity } from '../../contracts/activity.ts'

// Wire (snake_case) body for POST /ideas — mapped to the domain's CreateIdeaInput.
interface CreateIdeaBody {
  activity_type_id: string
  scope?: 'friends' | 'squad'
  squad_id?: string
  audience: { kind: 'all_friends' | 'people'; person_ids?: string[] }
  allow_suggestions?: boolean
  time_options?: string[]
  location_options?: string[]
  community_event_id?: string
}

// Ideas/activities lifecycle. See specs/api/ideas-activities.md. All authed.
const ideaRoutes: FastifyPluginAsync = async (fastify) => {
  const svc = new ActivityService(fastify.db)

  // Re-load + serialize a single activity for the response body.
  const respond = async (viewerId: string, activityId: string) => {
    const [row] = await fastify.db.select().from(activity).where(eq(activity.id, activityId))
    return serializeActivity(fastify.db, viewerId, row!)
  }

  fastify.post<{ Body: CreateIdeaBody }>(
    '/ideas',
    { preHandler: fastify.authenticate },
    async (request, reply) => {
      const b = request.body
      const id = await svc.createIdea(request.profileId!, {
        activityTypeId: b.activity_type_id,
        scope: b.scope,
        squadId: b.squad_id,
        audience: { kind: b.audience.kind, personIds: b.audience.person_ids },
        allowSuggestions: b.allow_suggestions,
        timeOptions: b.time_options,
        locationOptions: b.location_options,
        communityEventId: b.community_event_id,
      })
      reply.code(201)
      return respond(request.profileId!, id)
    },
  )

  fastify.put<{ Params: { id: string }; Body: { value: 'in' | 'interested' | 'next_time' } }>(
    '/ideas/:id/response',
    {
      preHandler: fastify.authenticate,
      schema: {
        body: {
          type: 'object',
          required: ['value'],
          properties: { value: { type: 'string', enum: ['in', 'interested', 'next_time'] } },
        },
      },
    },
    async (request) => {
      await svc.setResponse(request.profileId!, request.params.id, request.body.value)
      return respond(request.profileId!, request.params.id)
    },
  )

  fastify.delete<{ Params: { id: string } }>(
    '/ideas/:id/response',
    { preHandler: fastify.authenticate },
    async (request) => {
      await svc.clearResponse(request.profileId!, request.params.id)
      return respond(request.profileId!, request.params.id)
    },
  )

  fastify.post<{ Params: { id: string }; Body: { kind: 'time' | 'location'; label: string } }>(
    '/ideas/:id/options',
    {
      preHandler: fastify.authenticate,
      schema: {
        body: {
          type: 'object',
          required: ['kind', 'label'],
          properties: {
            kind: { type: 'string', enum: ['time', 'location'] },
            label: { type: 'string', minLength: 1 },
          },
        },
      },
    },
    async (request, reply) => {
      await svc.addOption(request.profileId!, request.params.id, request.body.kind, request.body.label)
      reply.code(201)
      return respond(request.profileId!, request.params.id)
    },
  )

  fastify.put<{ Params: { id: string }; Body: { option_id: string; voted: boolean } }>(
    '/ideas/:id/votes',
    {
      preHandler: fastify.authenticate,
      schema: {
        body: {
          type: 'object',
          required: ['option_id', 'voted'],
          properties: {
            option_id: { type: 'string' },
            voted: { type: 'boolean' },
          },
        },
      },
    },
    async (request) => {
      await svc.toggleVote(
        request.profileId!,
        request.params.id,
        request.body.option_id,
        request.body.voted,
      )
      return respond(request.profileId!, request.params.id)
    },
  )

  fastify.post<{
    Params: { id: string }
    Body: { time_option_id?: string; location_option_id?: string }
  }>(
    '/ideas/:id/confirm',
    { preHandler: fastify.authenticate },
    async (request) => {
      await svc.confirm(request.profileId!, request.params.id, {
        timeOptionId: request.body?.time_option_id,
        locationOptionId: request.body?.location_option_id,
      })
      return respond(request.profileId!, request.params.id)
    },
  )
}

export default ideaRoutes
