import type { FastifyPluginAsync } from 'fastify'

import { CommunityService } from '../../domain/community/service.ts'
import {
  serializeCommunity,
  serializeCommunityEvent,
} from '../../contracts/community.ts'

// Communities: open, followable groups. Followers discover/follow/RSVP; leaders
// create/edit communities and post/edit/delete events. See specs/api/communities.md.
const communityRoutes: FastifyPluginAsync = async (fastify) => {
  const communities = new CommunityService(fastify.db)

  fastify.get<{ Querystring: { search?: string } }>(
    '/communities',
    { preHandler: fastify.authenticate },
    async (request) => {
      const items = await communities.discover(request.profileId!, request.query.search)
      return { items: items.map(serializeCommunity) }
    },
  )

  // Create a community — the caller becomes its first leader.
  fastify.post<{
    Body: { name: string; tagline?: string; icon?: string; color?: string }
  }>(
    '/communities',
    {
      preHandler: fastify.authenticate,
      schema: {
        body: {
          type: 'object',
          required: ['name'],
          properties: {
            name: { type: 'string', minLength: 1 },
            tagline: { type: 'string' },
            icon: { type: 'string' },
            color: { type: 'string' },
          },
        },
      },
    },
    async (request, reply) => {
      const summary = await communities.create(request.profileId!, request.body)
      reply.code(201)
      return serializeCommunity(summary)
    },
  )

  // Edit a community — leader-only.
  fastify.patch<{
    Params: { id: string }
    Body: { name?: string; tagline?: string; icon?: string; color?: string }
  }>(
    '/communities/:id',
    {
      preHandler: fastify.authenticate,
      schema: {
        body: {
          type: 'object',
          properties: {
            name: { type: 'string', minLength: 1 },
            tagline: { type: 'string' },
            icon: { type: 'string' },
            color: { type: 'string' },
          },
        },
      },
    },
    async (request) => {
      const summary = await communities.update(
        request.profileId!,
        request.params.id,
        request.body,
      )
      return serializeCommunity(summary)
    },
  )

  // Post an event — leader-only.
  fastify.post<{
    Params: { id: string }
    Body: {
      title: string
      activity_type_id?: string
      time?: string
      recurrence?: string
      location?: string
    }
  }>(
    '/communities/:id/events',
    {
      preHandler: fastify.authenticate,
      schema: {
        body: {
          type: 'object',
          required: ['title'],
          properties: {
            title: { type: 'string', minLength: 1 },
            activity_type_id: { type: 'string' },
            time: { type: 'string' },
            recurrence: { type: 'string' },
            location: { type: 'string' },
          },
        },
      },
    },
    async (request, reply) => {
      const view = await communities.createEvent(request.profileId!, request.params.id, {
        title: request.body.title,
        activityTypeId: request.body.activity_type_id,
        time: request.body.time,
        recurrence: request.body.recurrence,
        location: request.body.location,
      })
      const c = await communities.get(view.event.communityId)
      reply.code(201)
      return serializeCommunityEvent(view, c)
    },
  )

  // Edit an event — leader-only.
  fastify.patch<{
    Params: { id: string }
    Body: {
      title?: string
      activity_type_id?: string
      time?: string
      recurrence?: string
      location?: string
    }
  }>(
    '/community-events/:id',
    {
      preHandler: fastify.authenticate,
      schema: {
        body: {
          type: 'object',
          properties: {
            title: { type: 'string', minLength: 1 },
            activity_type_id: { type: 'string' },
            time: { type: 'string' },
            recurrence: { type: 'string' },
            location: { type: 'string' },
          },
        },
      },
    },
    async (request) => {
      const view = await communities.updateEvent(request.profileId!, request.params.id, {
        title: request.body.title,
        activityTypeId: request.body.activity_type_id,
        time: request.body.time,
        recurrence: request.body.recurrence,
        location: request.body.location,
      })
      const c = await communities.get(view.event.communityId)
      return serializeCommunityEvent(view, c)
    },
  )

  // Cancel an event — leader-only.
  fastify.delete<{ Params: { id: string } }>(
    '/community-events/:id',
    { preHandler: fastify.authenticate },
    async (request, reply) => {
      await communities.deleteEvent(request.profileId!, request.params.id)
      reply.code(204)
    },
  )

  fastify.put<{ Params: { id: string }; Body: { follow: boolean } }>(
    '/communities/:id/follow',
    {
      preHandler: fastify.authenticate,
      schema: {
        body: {
          type: 'object',
          required: ['follow'],
          properties: { follow: { type: 'boolean' } },
        },
      },
    },
    async (request) => {
      const res = await communities.toggleFollow(
        request.profileId!,
        request.params.id,
        request.body.follow,
      )
      return { you_follow: res.youFollow, follower_count: res.followerCount }
    },
  )

  fastify.get<{ Params: { id: string } }>(
    '/communities/:id/events',
    { preHandler: fastify.authenticate },
    async (request) => {
      const c = await communities.get(request.params.id)
      const views = await communities.events(request.profileId!, request.params.id)
      return { items: views.map((v) => serializeCommunityEvent(v, c)) }
    },
  )

  fastify.put<{ Params: { id: string }; Body: { going?: boolean; public?: boolean } }>(
    '/community-events/:id/rsvp',
    {
      preHandler: fastify.authenticate,
      schema: {
        body: {
          type: 'object',
          properties: {
            going: { type: 'boolean' },
            public: { type: 'boolean' },
          },
        },
      },
    },
    async (request) => {
      const view = await communities.setRsvp(
        request.profileId!,
        request.params.id,
        request.body.going ?? false,
        request.body.public ?? false,
      )
      const c = await communities.get(view.event.communityId)
      return serializeCommunityEvent(view, c)
    },
  )
}

export default communityRoutes
