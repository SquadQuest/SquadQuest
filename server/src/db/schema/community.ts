import { pgTable, pgEnum, uuid, text, boolean, timestamp, primaryKey } from 'drizzle-orm/pg-core'

import { profile, topic } from './identity.ts'

export const communityRole = pgEnum('community_role', ['leader', 'follower'])

// Open, followable groups whose leaders broadcast events (specs/data-model.md).
export const community = pgTable('community', {
  id: uuid('id').primaryKey().defaultRandom(),
  name: text('name').notNull(),
  tagline: text('tagline'),
  icon: text('icon'), // emoji glyph
  color: text('color'),
  photo: text('photo'), // public media URL (cover image); see specs/api/uploads.md
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
})

// A follow (and leadership). Following is open/frictionless; only `leader` posts events.
export const communityMembership = pgTable(
  'community_membership',
  {
    communityId: uuid('community_id')
      .notNull()
      .references(() => community.id, { onDelete: 'cascade' }),
    profileId: uuid('profile_id')
      .notNull()
      .references(() => profile.id, { onDelete: 'cascade' }),
    role: communityRole('role').notNull().default('follower'),
  },
  (t) => [primaryKey({ columns: [t.communityId, t.profileId] })],
)

// A leader-broadcast event — born confirmed, recurring. Distinct from `activity`
// (no idea/voting stage). time/recurrence/location are display strings.
export const communityEvent = pgTable('community_event', {
  id: uuid('id').primaryKey().defaultRandom(),
  communityId: uuid('community_id')
    .notNull()
    .references(() => community.id, { onDelete: 'cascade' }),
  title: text('title').notNull(),
  activityTypeId: uuid('activity_type_id').references(() => topic.id),
  time: text('time'), // next occurrence, e.g. "Wed Apr 1 · 6:30pm"
  recurrence: text('recurrence'), // e.g. "Every other Wed"
  location: text('location'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
})

// The attendance visibility gradient. `going` → anonymous headcount; `public`
// additionally → public face-pile. `public` implies `going`.
export const communityEventRsvp = pgTable(
  'community_event_rsvp',
  {
    eventId: uuid('event_id')
      .notNull()
      .references(() => communityEvent.id, { onDelete: 'cascade' }),
    profileId: uuid('profile_id')
      .notNull()
      .references(() => profile.id, { onDelete: 'cascade' }),
    going: boolean('going').notNull().default(false),
    public: boolean('public').notNull().default(false),
  },
  (t) => [primaryKey({ columns: [t.eventId, t.profileId] })],
)
