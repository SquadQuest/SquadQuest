import type { FastifyPluginAsync } from 'fastify'

import { MessageService, type ThreadTargetType } from '../../domain/message/service.ts'
import { serializeMessages, serializeMessage } from '../../contracts/message.ts'
import { errors } from '../../contracts/errors.ts'

const DEFAULT_LIMIT = 50
const MAX_LIMIT = 100

// Shape of one image attachment in a message body (key + public URL from
// POST /v1/uploads). Shared by the squad-message and thread-reply routes.
export const ATTACHMENT_SCHEMA = {
  type: 'object',
  required: ['key', 'url'],
  properties: { key: { type: 'string' }, url: { type: 'string' } },
} as const

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

// targetType ∈ {activity, message} this stage (community_event arrives with communities).
function parseTargetType(raw: string): ThreadTargetType {
  if (raw === 'activity' || raw === 'message') return raw
  throw errors.badRequest('invalid_target', 'Unsupported thread target')
}

// Threads: reply conversations on activities / squad messages (specs/api/messages.md,
// behaviors/thread-drawer.md). All authed.
const messageRoutes: FastifyPluginAsync = async (fastify) => {
  const messages = new MessageService(fastify.db)

  fastify.get<{
    Params: { targetType: string; targetId: string }
    Querystring: { limit?: number; before?: string }
  }>(
    '/threads/:targetType/:targetId/messages',
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
      const targetType = parseTargetType(request.params.targetType)
      const limit = Math.min(request.query.limit ?? DEFAULT_LIMIT, MAX_LIMIT)
      const before = request.query.before ? decodeCursor(request.query.before) : undefined
      const rows = await messages.threadMessages(
        request.profileId!,
        targetType,
        request.params.targetId,
        limit + 1,
        before,
      )
      const page = rows.slice(0, limit)
      const last = page.at(-1)
      const nextCursor =
        rows.length > limit && last ? encodeCursor(last.createdAt, last.id) : null
      const items = await serializeMessages(fastify.db, page)
      return { items, next_cursor: nextCursor }
    },
  )

  fastify.post<{
    Params: { targetType: string; targetId: string }
    Body: { body?: string; attachments?: { key: string; url: string }[] }
  }>(
    '/threads/:targetType/:targetId/messages',
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
      const targetType = parseTargetType(request.params.targetType)
      const row = await messages.postThreadReply(
        request.profileId!,
        targetType,
        request.params.targetId,
        request.body.body ?? '',
        request.body.attachments ?? [],
      )
      reply.code(201)
      return serializeMessage(fastify.db, row)
    },
  )
}

export default messageRoutes
