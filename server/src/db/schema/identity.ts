import {
  pgTable,
  pgEnum,
  uuid,
  text,
  timestamp,
  unique,
  primaryKey,
} from 'drizzle-orm/pg-core'

// A person. `phone` is the identity bridge from v1 (see
// specs/behaviors/v1-migration.md); `claimed_at` null = a pre-migrated shell
// not yet logged into v2.
export const profile = pgTable('profile', {
  id: uuid('id').primaryKey().defaultRandom(),
  phone: text('phone').notNull().unique(),
  firstName: text('first_name'),
  lastName: text('last_name'),
  photo: text('photo'),
  claimedAt: timestamp('claimed_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true })
    .notNull()
    .defaultNow(),
})

// No `declined`: a dismissed request is ignored (silent + recoverable), never
// declined. See principles.md#dismissal-is-silent-and-reversible.
export const friendshipStatus = pgEnum('friendship_status', ['requested', 'accepted'])

// The double-opt-in graph. A pair is "friends" when status = accepted.
export const friendship = pgTable(
  'friendship',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    requester: uuid('requester')
      .notNull()
      .references(() => profile.id, { onDelete: 'cascade' }),
    requestee: uuid('requestee')
      .notNull()
      .references(() => profile.id, { onDelete: 'cascade' }),
    status: friendshipStatus('status').notNull().default('requested'),
    // Set when the requestee ignored an incoming request: the edge stays
    // `requested` (the sender still sees pending) but it leaves the requestee's
    // incoming list for their Ignored surface. Silent + recoverable.
    ignoredAt: timestamp('ignored_at', { withTimezone: true }),
    createdAt: timestamp('created_at', { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (t) => [unique('friendship_pair').on(t.requester, t.requestee)],
)

// The interest taxonomy (noun-verb, e.g. "Go Hiking").
export const topic = pgTable('topic', {
  id: uuid('id').primaryKey().defaultRandom(),
  noun: text('noun').notNull(),
  verb: text('verb').notNull(),
  label: text('label').notNull(),
})

// Per-user interest subscriptions.
export const topicSubscription = pgTable(
  'topic_subscription',
  {
    topicId: uuid('topic_id')
      .notNull()
      .references(() => topic.id, { onDelete: 'cascade' }),
    profileId: uuid('profile_id')
      .notNull()
      .references(() => profile.id, { onDelete: 'cascade' }),
  },
  (t) => [primaryKey({ columns: [t.topicId, t.profileId] })],
)
