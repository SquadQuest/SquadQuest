import type { FastifyBaseLogger } from 'fastify'

// Swappable OTP delivery. Stage 1 ships ConsoleOtpProvider (logs the code); a
// real SMS provider (Twilio Verify-class) is a later-stage follow-up. See
// specs/api/auth.md and specs/architecture.md.
export interface OtpProvider {
  send(phone: string, code: string): Promise<void>
}

export class ConsoleOtpProvider implements OtpProvider {
  constructor(private readonly log: FastifyBaseLogger) {}

  async send(phone: string, code: string): Promise<void> {
    this.log.info({ phone, code }, `[dev OTP] code for ${phone}: ${code}`)
  }
}
