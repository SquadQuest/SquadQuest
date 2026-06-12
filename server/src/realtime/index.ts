import fp from 'fastify-plugin'
import postgres from 'postgres'

// Server→client live updates: SSE fanned out via Postgres LISTEN/NOTIFY. A pure
// enhancement, never load-bearing — see specs/behaviors/realtime.md.

const CHANNEL = 'sq_events'

// A realtime event: a small id-only payload that nudges clients to refetch.
export interface RealtimeEvent {
  type: 'activity.created' | 'message.created'
  // routing ids — just enough for a subscriber to decide relevance + invalidate.
  [key: string]: unknown
}

// A connected SSE subscriber: their profile id, a per-event visibility predicate
// (reuses the REST gates), and a sink that writes one event to their stream.
export interface Subscriber {
  profileId: string
  canSee: (event: RealtimeEvent) => Promise<boolean>
  send: (event: RealtimeEvent) => void
}

export interface Realtime {
  add(sub: Subscriber): () => void // returns an unsubscribe fn
  publish(event: RealtimeEvent): Promise<void>
  subscriberCount(): number
}

declare module 'fastify' {
  interface FastifyInstance {
    realtime: Realtime
  }
}

export default fp(async (fastify) => {
  const subscribers = new Set<Subscriber>()

  // Dedicated single LISTEN connection (separate from the query pool). On NOTIFY,
  // fan out to the subscribers that may see the event.
  const listener = postgres(fastify.config.DATABASE_URL, { max: 1 })

  async function fanOut(raw: string) {
    let event: RealtimeEvent
    try {
      event = JSON.parse(raw) as RealtimeEvent
    } catch {
      return // ignore malformed payloads
    }
    // Snapshot to avoid mutation-during-iteration; visibility is async + per-sub.
    await Promise.all(
      [...subscribers].map(async (sub) => {
        try {
          if (await sub.canSee(event)) sub.send(event)
        } catch {
          /* a failing visibility check just drops the event for that sub */
        }
      }),
    )
  }

  await listener.listen(CHANNEL, (raw) => {
    void fanOut(raw)
  })

  const realtime: Realtime = {
    add(sub) {
      subscribers.add(sub)
      return () => subscribers.delete(sub)
    },
    // Publish via NOTIFY so every server process (and this one) fans out uniformly.
    async publish(event) {
      try {
        await fastify.sql.notify(CHANNEL, JSON.stringify(event))
      } catch (err) {
        // Never let a realtime failure break the originating write — it's an
        // enhancement. Log and move on.
        fastify.log.warn({ err }, 'realtime publish failed')
      }
    },
    subscriberCount: () => subscribers.size,
  }

  fastify.decorate('realtime', realtime)

  fastify.addHook('onClose', async () => {
    await listener.end({ timeout: 5 })
  })
})
