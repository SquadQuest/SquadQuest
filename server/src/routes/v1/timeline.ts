import type { FastifyPluginAsync } from 'fastify'

import { ActivityService } from '../../domain/activity/service.ts'
import { serializeActivities } from '../../contracts/activity.ts'

const DEFAULT_LIMIT = 50
const MAX_LIMIT = 100

// Opaque cursor over (created_at, id).
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

// GET /v1/timeline/friends — the My Friends feed (ideas/activities only),
// cursor-paginated newest-first. See specs/api/timeline.md.
const timelineRoutes: FastifyPluginAsync = async (fastify) => {
  const svc = new ActivityService(fastify.db)

  fastify.get<{ Querystring: { limit?: number; before?: string } }>(
    '/timeline/friends',
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
      const limit = Math.min(request.query.limit ?? DEFAULT_LIMIT, MAX_LIMIT)
      const before = request.query.before ? decodeCursor(request.query.before) : undefined

      // Fetch one extra to know whether there's a next page.
      const rows = await svc.friendsTimeline(request.profileId!, limit + 1, before)
      const page = rows.slice(0, limit)
      const last = page.at(-1)
      const nextCursor =
        rows.length > limit && last ? encodeCursor(last.createdAt, last.id) : null

      const items = await serializeActivities(fastify.db, request.profileId!, page)
      return { items, next_cursor: nextCursor }
    },
  )
}

export default timelineRoutes
