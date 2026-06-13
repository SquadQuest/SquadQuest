import type { FastifyPluginAsync } from 'fastify'

import { TopicService } from '../../domain/topic/service.ts'
import { serializeTopic } from '../../contracts/topic.ts'

// Activity types: official-first list + search, and community create (dedicated;
// on-the-fly lives on the ideas/wants routes). See specs/api/topics.md.
const topicRoutes: FastifyPluginAsync = async (fastify) => {
  const svc = new TopicService(fastify.db)

  fastify.get<{ Querystring: { search?: string } }>(
    '/topics',
    { preHandler: fastify.authenticate },
    async (request) => {
      const rows = await svc.list(request.query.search)
      return { items: rows.map(serializeTopic) }
    },
  )

  // Create a community type. Normalized-match reuse → 200 with the existing topic;
  // a genuinely new label → 201 with the created community topic.
  fastify.post<{ Body: { label: string } }>(
    '/topics',
    {
      preHandler: fastify.authenticate,
      schema: {
        body: {
          type: 'object',
          required: ['label'],
          properties: { label: { type: 'string' } },
        },
      },
    },
    async (request, reply) => {
      const { topic, created } = await svc.findOrCreate(
        request.body.label,
        request.profileId!,
      )
      reply.code(created ? 201 : 200)
      return serializeTopic(topic)
    },
  )
}

export default topicRoutes
