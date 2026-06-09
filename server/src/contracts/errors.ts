import type { FastifyReply } from 'fastify'

// The standard error envelope from specs/api/conventions.md. Clients branch on
// `error.code` (stable), never on `message`. `upgrade` is present only on 426.
export interface ErrorEnvelope {
  error: {
    code: string
    message: string
    details?: Record<string, unknown>
  }
  upgrade?: {
    min_build: number
    store_url: string
  }
}

// A thrown error that maps to the envelope. The global error handler (app.ts)
// turns these into the right status + body.
export class ApiError extends Error {
  constructor(
    readonly statusCode: number,
    readonly code: string,
    message: string,
    readonly details?: Record<string, unknown>,
  ) {
    super(message)
    this.name = 'ApiError'
  }
}

// Common constructors (codes match specs/api/*).
export const errors = {
  unauthorized: (message = 'Authentication required') =>
    new ApiError(401, 'unauthorized', message),
  forbidden: (code: string, message: string) =>
    new ApiError(403, code, message),
  rateLimited: (message = 'Too many requests') =>
    new ApiError(429, 'rate_limited', message),
  badRequest: (code: string, message: string, details?: Record<string, unknown>) =>
    new ApiError(400, code, message, details),
}

export function sendError(reply: FastifyReply, err: ApiError): void {
  const body: ErrorEnvelope = {
    error: { code: err.code, message: err.message, details: err.details },
  }
  reply.code(err.statusCode).send(body)
}
