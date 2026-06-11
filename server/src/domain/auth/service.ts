import { createHash, randomBytes } from 'node:crypto'
import { eq } from 'drizzle-orm'

import type { Database } from '../../db/index.ts'
import { profile, refreshToken } from '../../db/schema/index.ts'
import { ApiError } from '../../contracts/errors.ts'
import { normalizePhone } from './phone.ts'
import type { OtpProvider } from './otp-provider.ts'

const REFRESH_TTL_MS = 30 * 24 * 60 * 60 * 1000

const sha256 = (s: string) => createHash('sha256').update(s).digest('hex')

export interface VerifyResult {
  profileId: string
  accessToken: string
  refreshToken: string
  claimedV1: boolean
}

export class AuthService {
  constructor(
    private readonly db: Database,
    private readonly otp: OtpProvider,
    private readonly signAccessToken: (profileId: string) => string,
  ) {}

  // Start verification via the provider (SMS in prod, console in dev). Always
  // succeeds for a valid-format number (don't reveal whether it's known).
  async requestOtp(rawPhone: string): Promise<{ expiresIn: number }> {
    const phone = normalizePhone(rawPhone)
    await this.otp.start(phone)
    return { expiresIn: this.otp.ttlSeconds }
  }

  // Verify the code via the provider, then claim a pre-migrated shell or create a
  // fresh profile, and issue tokens. See specs/behaviors/v1-migration.md.
  async verifyOtp(rawPhone: string, code: string): Promise<VerifyResult> {
    const phone = normalizePhone(rawPhone)

    if (!(await this.otp.check(phone, code))) {
      throw new ApiError(400, 'otp_invalid', 'Incorrect code')
    }

    // Claim shell or create fresh.
    const [existing] = await this.db.select().from(profile).where(eq(profile.phone, phone))
    let profileId: string
    let claimedV1 = false
    if (existing) {
      profileId = existing.id
      if (existing.claimedAt === null) {
        await this.db
          .update(profile)
          .set({ claimedAt: new Date() })
          .where(eq(profile.id, existing.id))
        claimedV1 = true // an unclaimed (pre-migrated) shell became active
      }
    } else {
      const [created] = await this.db
        .insert(profile)
        .values({ phone, claimedAt: new Date() })
        .returning({ id: profile.id })
      profileId = created!.id
    }

    const tokens = await this.issueTokens(profileId)
    return { profileId, ...tokens, claimedV1 }
  }

  // Rotate a refresh token: revoke the presented one, issue a fresh pair.
  async refresh(rawToken: string): Promise<{ accessToken: string; refreshToken: string }> {
    const hash = sha256(rawToken)
    const [row] = await this.db
      .select()
      .from(refreshToken)
      .where(eq(refreshToken.tokenHash, hash))

    if (!row || row.revokedAt !== null) {
      throw new ApiError(401, 'refresh_invalid', 'Invalid refresh token')
    }
    if (row.expiresAt.getTime() < Date.now()) {
      throw new ApiError(401, 'refresh_invalid', 'Refresh token expired')
    }

    await this.revoke(hash)
    return this.issueTokens(row.profileId)
  }

  async logout(rawToken: string): Promise<void> {
    await this.revoke(sha256(rawToken))
  }

  private async revoke(tokenHash: string): Promise<void> {
    await this.db
      .update(refreshToken)
      .set({ revokedAt: new Date() })
      .where(eq(refreshToken.tokenHash, tokenHash))
  }

  private async issueTokens(
    profileId: string,
  ): Promise<{ accessToken: string; refreshToken: string }> {
    const raw = randomBytes(32).toString('base64url')
    await this.db.insert(refreshToken).values({
      profileId,
      tokenHash: sha256(raw),
      expiresAt: new Date(Date.now() + REFRESH_TTL_MS),
    })
    return { accessToken: this.signAccessToken(profileId), refreshToken: raw }
  }
}
