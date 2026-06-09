import { pgTable, uuid, text, timestamp, integer } from 'drizzle-orm/pg-core'

import { profile } from './identity.ts'

// Short-lived OTP challenges, keyed by normalized (E.164) phone. The code is
// stored hashed; `attempts` supports basic rate limiting.
export const otpCode = pgTable('otp_code', {
  phone: text('phone').primaryKey(),
  codeHash: text('code_hash').notNull(),
  expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
  attempts: integer('attempts').notNull().default(0),
  createdAt: timestamp('created_at', { withTimezone: true })
    .notNull()
    .defaultNow(),
})

// Rotating refresh tokens (stored hashed). `revokedAt` set on logout/rotation.
export const refreshToken = pgTable('refresh_token', {
  id: uuid('id').primaryKey().defaultRandom(),
  profileId: uuid('profile_id')
    .notNull()
    .references(() => profile.id, { onDelete: 'cascade' }),
  tokenHash: text('token_hash').notNull().unique(),
  expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
  revokedAt: timestamp('revoked_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true })
    .notNull()
    .defaultNow(),
})
