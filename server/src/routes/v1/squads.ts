import type { FastifyPluginAsync } from 'fastify'

import { SquadService } from '../../domain/squad/service.ts'
import { ActivityService } from '../../domain/activity/service.ts'
import { serializeSquadSummary, serializeSquadDetail } from '../../contracts/squad.ts'
import { serializeActivities } from '../../contracts/activity.ts'

const DEFAULT_LIMIT = 50
const MAX_LIMIT = 100

function encodeCursor(createdAt: Date, id: string): string {
  return Buffer.from(`${createdAt.toISOString()}|${id}`).toString('base64url')
}
function decodeCursor(raw: string): { createdAt: Date; id: string } | undefined {
  try {
    const [iso, id] = Buffer.from(raw, 'base64url').toString().split('|')
    if (!iso || !id) return undefined
    return { createdAt: new Date(iso), id }
  } catch {
    return undefined
  }
}

// Squads: closed, persistent named groups (specs/screens/squads.md,
// behaviors/context-selector.md). All authed.
const squadRoutes: FastifyPluginAsync = async (fastify) => {
  const squads = new SquadService(fastify.db)
  const activities = new ActivityService(fastify.db)

  fastify.post<{ Body: { name: string; member_ids?: string[] } }>(
    '/squads',
    {
      preHandler: fastify.authenticate,
      schema: {
        body: {
          type: 'object',
          required: ['name'],
          properties: {
            name: { type: 'string', minLength: 1 },
            member_ids: { type: 'array', items: { type: 'string' } },
          },
        },
      },
    },
    async (request, reply) => {
      const id = await squads.createSquad(
        request.profileId!,
        request.body.name,
        request.body.member_ids ?? [],
      )
      reply.code(201)
      return serializeSquadDetail(await squads.getSquad(request.profileId!, id))
    },
  )

  fastify.get('/squads', { preHandler: fastify.authenticate }, async (request) => {
    const mine = await squads.listMySquads(request.profileId!)
    return { items: mine.map(serializeSquadSummary) }
  })

  fastify.get<{ Params: { id: string } }>(
    '/squads/:id',
    { preHandler: fastify.authenticate },
    async (request) =>
      serializeSquadDetail(await squads.getSquad(request.profileId!, request.params.id)),
  )

  fastify.post<{ Params: { id: string }; Body: { profile_id: string } }>(
    '/squads/:id/members',
    {
      preHandler: fastify.authenticate,
      schema: {
        body: {
          type: 'object',
          required: ['profile_id'],
          properties: { profile_id: { type: 'string' } },
        },
      },
    },
    async (request) => {
      await squads.addMember(request.profileId!, request.params.id, request.body.profile_id)
      return serializeSquadDetail(await squads.getSquad(request.profileId!, request.params.id))
    },
  )

  fastify.get<{ Params: { id: string }; Querystring: { limit?: number; before?: string } }>(
    '/squads/:id/timeline',
    {
      preHandler: fastify.authenticate,
      schema: {
        querystring: {
          type: 'object',
          properties: {
            limit: { type: 'integer', minimum: 1, maximum: MAX_LIMIT },
            before: { type: 'string' },
          },
        },
      },
    },
    async (request) => {
      const viewer = request.profileId!
      const squadId = request.params.id
      // Membership-gates the read (404s for non-members, indistinguishable from missing).
      await squads.getSquad(viewer, squadId)

      const limit = Math.min(request.query.limit ?? DEFAULT_LIMIT, MAX_LIMIT)
      const before = request.query.before ? decodeCursor(request.query.before) : undefined
      const rows = await activities.squadTimeline(squadId, limit + 1, before)
      const page = rows.slice(0, limit)
      const last = page.at(-1)
      const nextCursor =
        rows.length > limit && last ? encodeCursor(last.createdAt, last.id) : null
      const items = await serializeActivities(fastify.db, viewer, page)
      return { items, next_cursor: nextCursor }
    },
  )
}

export default squadRoutes
