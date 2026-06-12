import {
  pgTable,
  pgEnum,
  uuid,
  text,
  timestamp,
  primaryKey,
} from 'drizzle-orm/pg-core'

import { profile, topic } from './identity.ts'
import { responseValue } from './activity.ts'

// A loose, shared pre-activity: an intent + the friends you'd do it with, captured
// before there's a time/place. See specs/data-model.md (want) + specs/api/wants.md.
// Privacy is derived: no invitees ⇒ private; inviting a friend shares it with them.
export const wantKind = pgEnum('want_kind', ['one_shot', 'ongoing'])

export const want = pgTable('want', {
  id: uuid('id').primaryKey().defaultRandom(),
  ownerId: uuid('owner_id')
    .notNull()
    .references(() => profile.id, { onDelete: 'cascade' }),
  // Required: every want carries the noun-verb taxonomy so it's "ready to go".
  activityTypeId: uuid('activity_type_id')
    .notNull()
    .references(() => topic.id),
  title: text('title'),
  location: text('location'),
  notes: text('notes'),
  // one_shot archives once promoted; ongoing spawns activities repeatedly.
  kind: wantKind('kind').notNull().default('one_shot'),
  archivedAt: timestamp('archived_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
})

// A friend the owner tagged onto a want, with that friend's soft response. Reuses
// the activity response vocabulary (in/interested/next_time); null = invited-not-yet-
// responded. ignoredAt set ⇒ the invitee ignored it (silent + recoverable; never
// surfaced to the owner — see the dismissal-is-silent principle).
export const wantInvite = pgTable(
  'want_invite',
  {
    wantId: uuid('want_id')
      .notNull()
      .references(() => want.id, { onDelete: 'cascade' }),
    profileId: uuid('profile_id')
      .notNull()
      .references(() => profile.id, { onDelete: 'cascade' }),
    response: responseValue('response'),
    ignoredAt: timestamp('ignored_at', { withTimezone: true }),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [primaryKey({ columns: [t.wantId, t.profileId] })],
)
