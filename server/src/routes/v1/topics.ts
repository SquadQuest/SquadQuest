import type { FastifyPluginAsync } from 'fastify'
import { asc } from 'drizzle-orm'

import { topic } from '../../db/schema/index.ts'
import { serializeTopic } from '../../contracts/topic.ts'

// GET /v1/topics — the activity types available when composing an idea.
// See specs/api/ideas-activities.md.
const topicRoutes: FastifyPluginAsync = async (fastify) => {
  fastify.get('/topics', { preHandler: fastify.authenticate }, async () => {
    const rows = await fastify.db.select().from(topic).orderBy(asc(topic.label))
    return { items: rows.map(serializeTopic) }
  })
}

export default topicRoutes
