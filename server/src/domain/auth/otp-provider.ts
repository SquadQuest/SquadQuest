import { createHash, randomInt } from 'node:crypto'
import { eq } from 'drizzle-orm'
import type { FastifyBaseLogger } from 'fastify'

import type { Database } from '../../db/index.ts'
import { otpCode } from '../../db/schema/index.ts'
import { ApiError, errors } from '../../contracts/errors.ts'

// OTP delivery + verification. Twilio Verify (and similar) own code generation
// AND checking, so the abstraction is start/check rather than one-way send:
//   start(phone)         — begin a verification (deliver a code)
//   check(phone, code)   — true if the code is correct
// AuthService stays provider-agnostic; only the SMS vs dev-console mechanism varies.
// See specs/api/auth.md.
export interface OtpProvider {
  start(phone: string): Promise<void>
  check(phone: string, code: string): Promise<boolean>
  // The TTL (seconds) advertised to clients via `expires_in`. Advisory.
  readonly ttlSeconds: number
}

const OTP_TTL_MS = 5 * 60 * 1000
const OTP_MAX_ATTEMPTS = 5
const sha256 = (s: string) => createHash('sha256').update(s).digest('hex')

// Dev provider: self-manages codes in the `otp_code` table and logs the code
// instead of sending an SMS. Used locally + in tests (no external dependency).
export class ConsoleOtpProvider implements OtpProvider {
  readonly ttlSeconds = Math.floor(OTP_TTL_MS / 1000)

  constructor(
    private readonly db: Database,
    private readonly log: FastifyBaseLogger,
  ) {}

  async start(phone: string): Promise<void> {
    const code = String(randomInt(0, 1_000_000)).padStart(6, '0')
    const expiresAt = new Date(Date.now() + OTP_TTL_MS)
    const codeHash = sha256(`${phone}:${code}`)
    await this.db
      .insert(otpCode)
      .values({ phone, codeHash, expiresAt, attempts: 0 })
      .onConflictDoUpdate({
        target: otpCode.phone,
        set: { codeHash, expiresAt, attempts: 0 },
      })
    this.log.info({ phone, code }, `[dev OTP] code for ${phone}: ${code}`)
  }

  async check(phone: string, code: string): Promise<boolean> {
    const [row] = await this.db.select().from(otpCode).where(eq(otpCode.phone, phone))
    if (!row || row.expiresAt.getTime() < Date.now()) {
      throw new ApiError(400, 'otp_expired', 'Code expired or not found')
    }
    if (row.attempts >= OTP_MAX_ATTEMPTS) {
      throw errors.rateLimited('Too many attempts; request a new code')
    }
    if (row.codeHash !== sha256(`${phone}:${code}`)) {
      await this.db
        .update(otpCode)
        .set({ attempts: row.attempts + 1 })
        .where(eq(otpCode.phone, phone))
      return false
    }
    await this.db.delete(otpCode).where(eq(otpCode.phone, phone)) // consume
    return true
  }
}

export interface TwilioVerifyConfig {
  accountSid: string
  authToken: string
  serviceSid: string
}

// Production provider: delegates code gen + delivery + checking to Twilio Verify.
// We never see or store the code. REST API (no SDK) with basic auth.
export class TwilioVerifyOtpProvider implements OtpProvider {
  // Verify's default code TTL is ~10 min; advertise that to clients.
  readonly ttlSeconds = 600

  constructor(
    private readonly cfg: TwilioVerifyConfig,
    private readonly log: FastifyBaseLogger,
  ) {}

  private get authHeader(): string {
    return (
      'Basic ' +
      Buffer.from(`${this.cfg.accountSid}:${this.cfg.authToken}`).toString('base64')
    )
  }

  private url(path: string): string {
    return `https://verify.twilio.com/v2/Services/${this.cfg.serviceSid}/${path}`
  }

  async start(phone: string): Promise<void> {
    const res = await fetch(this.url('Verifications'), {
      method: 'POST',
      headers: {
        Authorization: this.authHeader,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({ To: phone, Channel: 'sms' }),
    })
    if (!res.ok) {
      const detail = await res.text()
      this.log.error({ status: res.status, detail }, 'twilio verify start failed')
      if (res.status === 429) throw errors.rateLimited('Too many requests; try again shortly')
      throw errors.badRequest('phone_invalid', 'Could not send a verification code')
    }
  }

  async check(phone: string, code: string): Promise<boolean> {
    const res = await fetch(this.url('VerificationCheck'), {
      method: 'POST',
      headers: {
        Authorization: this.authHeader,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({ To: phone, Code: code }),
    })
    // Verify returns 404 when the verification expired or was already consumed.
    if (res.status === 404) {
      throw new ApiError(400, 'otp_expired', 'Code expired or not found')
    }
    if (res.status === 429) {
      throw errors.rateLimited('Too many attempts; request a new code')
    }
    if (!res.ok) {
      const detail = await res.text()
      this.log.error({ status: res.status, detail }, 'twilio verify check failed')
      throw errors.badRequest('otp_invalid', 'Could not verify the code')
    }
    const body = (await res.json()) as { status?: string }
    return body.status === 'approved'
  }
}
