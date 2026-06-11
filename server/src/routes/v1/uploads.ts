import type { FastifyPluginAsync } from 'fastify'

import { StorageService } from '../../domain/storage/service.ts'
import { ApiError } from '../../contracts/errors.ts'

// POST /v1/uploads — request a signed target to PUT an image directly to storage,
// then reference the returned key (the API never proxies bytes). The public URL is
// what gets stored on the resource (profile.photo, community.photo, attachments).
// See specs/api/uploads.md + conventions.md §Storage.
const uploadRoutes: FastifyPluginAsync = async (fastify) => {
  const bucket = fastify.config.MEDIA_BUCKET
  // No bucket configured (local dev without GCS) → the endpoint 503s rather than
  // crashing the server at boot.
  const storage = bucket ? new StorageService(bucket) : null

  fastify.post<{ Body: { kind: string; content_type: string } }>(
    '/uploads',
    {
      preHandler: fastify.authenticate,
      schema: {
        body: {
          type: 'object',
          required: ['kind', 'content_type'],
          properties: {
            kind: { type: 'string' },
            content_type: { type: 'string' },
          },
        },
      },
    },
    async (request) => {
      if (!storage) {
        throw new ApiError(503, 'storage_unavailable', 'Uploads are not configured')
      }
      return storage.createUploadTarget(request.body.kind, request.body.content_type)
    },
  )
}

export default uploadRoutes
