import fp from 'fastify-plugin'

import { type ErrorEnvelope } from '../contracts/errors.ts'

// Parsed `X-SquadQuest-Client: <platform>/<version>+<build>` (e.g. ios/1.4.2+312).
export interface ClientBuild {
  platform: string
  version: string
  build: number
}

declare module 'fastify' {
  interface FastifyRequest {
    clientBuild: ClientBuild | null
  }
}

const HEADER = 'x-squadquest-client'

export function parseClientHeader(value: string | undefined): ClientBuild | null {
  if (!value) return null
  const m = /^([^/]+)\/(.+)\+(\d+)$/.exec(value.trim())
  if (!m) return null
  return { platform: m[1]!, version: m[2]!, build: Number(m[3]) }
}

// Parses the client-build header onto request.clientBuild (telemetry) and
// enforces the upgrade floor: a present build below MIN_SUPPORTED_BUILD gets a
// 426 with the upgrade envelope. See specs/api/conventions.md.
//
// Stage 1 simplification: the header is not hard-required (the spec says it is);
// when absent we allow the request. Tightening that is a later-stage follow-up.
export default fp(async (fastify) => {
  const floor = fastify.config.MIN_SUPPORTED_BUILD

  fastify.decorateRequest('clientBuild', null)

  fastify.addHook('onRequest', async (request, reply) => {
    const build = parseClientHeader(request.headers[HEADER] as string | undefined)
    request.clientBuild = build

    if (floor > 0 && build && build.build < floor) {
      const body: ErrorEnvelope = {
        error: {
          code: 'upgrade_required',
          message: 'This app version is no longer supported. Please update.',
        },
        upgrade: { min_build: floor, store_url: 'https://squadquest.app' },
      }
      // Return the reply to halt the request lifecycle (don't run the route).
      return reply.code(426).send(body)
    }
  })
})
