import type { FastifyPluginAsync } from 'fastify'
import { eq } from 'drizzle-orm'

import { activity } from '../../db/schema/index.ts'
import { ActivityService } from '../../domain/activity/service.ts'
import { SquadService } from '../../domain/squad/service.ts'
import { MessageService } from '../../domain/message/service.ts'
import type { RealtimeEvent } from '../../realtime/index.ts'

const HEARTBEAT_MS = 25_000

// GET /v1/stream — authenticated SSE. Token via Authorization header OR
// ?access_token= (EventSource can't set headers). Events are id-only nudges to
// refetch; a subscriber only receives an event it could see via REST. See
// specs/behaviors/realtime.md.
const streamRoutes: FastifyPluginAsync = async (fastify) => {
  const activities = new ActivityService(fastify.db)
  const squads = new SquadService(fastify.db)

  // Whether `viewer` may see the resource behind `event` — reuses the REST gates.
  async function canSee(viewerId: string, event: RealtimeEvent): Promise<boolean> {
    if (event.type === 'activity.created') {
      const [act] = await fastify.db
        .select()
        .from(activity)
        .where(eq(activity.id, String(event.id)))
      return act ? activities.canView(viewerId, act) : false
    }
    if (event.type === 'message.created') {
      // squad message → squad members; thread reply → reuse the thread gate.
      if (event.squad_id) {
        return squads.isMember(String(event.squad_id), viewerId)
      }
      if (event.thread_target_type && event.thread_target_id) {
        return new MessageService(fastify.db).canSeeThread(
          viewerId,
          String(event.thread_target_type) as never,
          String(event.thread_target_id),
        )
      }
      return false
    }
    return false
  }

  fastify.get<{ Querystring: { access_token?: string } }>(
    '/stream',
    async (request, reply) => {
      const headerToken = (() => {
        const h = request.headers.authorization
        if (!h) return undefined
        const [scheme, t] = h.split(' ')
        return scheme?.toLowerCase() === 'bearer' ? t : undefined
      })()
      const profileId = fastify.verifyAccessToken(
        headerToken ?? request.query.access_token,
      )
      if (!profileId) {
        reply.code(401).send({ error: { code: 'unauthorized', message: 'Auth required' } })
        return
      }

      const res = reply.raw
      res.writeHead(200, {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        Connection: 'keep-alive',
        'X-Accel-Buffering': 'no',
      })
      res.write('retry: 3000\n\n') // client reconnect backoff hint
      res.write(': connected\n\n')

      const send = (event: RealtimeEvent) => {
        res.write(`event: ${event.type}\n`)
        res.write(`data: ${JSON.stringify(event)}\n\n`)
      }

      const unsubscribe = fastify.realtime.add({
        profileId,
        canSee: (event) => canSee(profileId, event),
        send,
      })

      const heartbeat = setInterval(() => res.write(': ping\n\n'), HEARTBEAT_MS)

      const cleanup = () => {
        clearInterval(heartbeat)
        unsubscribe()
      }
      request.raw.on('close', cleanup)

      // Hand the socket to us; Fastify won't try to send its own response.
      reply.hijack()
    },
  )
}

export default streamRoutes
