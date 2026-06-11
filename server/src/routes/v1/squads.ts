import type { FastifyPluginAsync } from 'fastify'

import { SquadService } from '../../domain/squad/service.ts'
import { ActivityService } from '../../domain/activity/service.ts'
import { MessageService } from '../../domain/message/service.ts'
import { serializeSquadSummary, serializeSquadDetail } from '../../contracts/squad.ts'
import { serializeActivities } from '../../contracts/activity.ts'
import { serializeMessages, serializeMessage } from '../../contracts/message.ts'
import { ATTACHMENT_SCHEMA } from './messages.ts'

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
  const messages = new MessageService(fastify.db)

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

      // Heterogeneous feed: squad-scoped activities + top-level squad messages,
      // each type-tagged and interleaved by created_at (specs/screens/squads.md).
      const [actRows, msgRows] = await Promise.all([
        activities.squadTimeline(squadId, limit + 1, before),
        messages.squadMessages(squadId, limit + 1, before),
      ])
      const [actItems, msgItems] = await Promise.all([
        serializeActivities(fastify.db, viewer, actRows),
        serializeMessages(fastify.db, msgRows),
      ])
      const merged = [
        ...actItems.map((a) => ({ type: 'activity' as const, ...a })),
        ...msgItems.map((m) => ({ type: 'message' as const, ...m })),
      ].sort((a, b) =>
        a.created_at === b.created_at
          ? (a.id < b.id ? 1 : -1)
          : (a.created_at < b.created_at ? 1 : -1),
      )
      const page = merged.slice(0, limit)
      const last = page.at(-1)
      const nextCursor =
        merged.length > limit && last
          ? encodeCursor(new Date(last.created_at), last.id)
          : null
      return { items: page, next_cursor: nextCursor }
    },
  )

  // Post a top-level message to a squad timeline (member-gated).
  fastify.post<{
    Params: { id: string }
    Body: { body?: string; attachments?: { key: string; url: string }[] }
  }>(
    '/squads/:id/messages',
    {
      preHandler: fastify.authenticate,
      schema: {
        body: {
          type: 'object',
          properties: {
            body: { type: 'string' },
            attachments: { type: 'array', items: ATTACHMENT_SCHEMA },
          },
        },
      },
    },
    async (request, reply) => {
      const row = await messages.postSquadMessage(
        request.profileId!,
        request.params.id,
        request.body.body ?? '',
        request.body.attachments ?? [],
      )
      reply.code(201)
      return serializeMessage(fastify.db, row)
    },
  )
}

export default squadRoutes
