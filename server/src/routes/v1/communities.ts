import type { FastifyPluginAsync } from 'fastify'

import { CommunityService } from '../../domain/community/service.ts'
import {
  serializeCommunity,
  serializeCommunityEvent,
} from '../../contracts/community.ts'

// Communities: open, followable groups; followers discover/follow/RSVP. Leader
// tooling (create/edit, post events) is deferred. See specs/api/communities.md.
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
