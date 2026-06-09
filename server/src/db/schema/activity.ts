import {
  pgTable,
  pgEnum,
  uuid,
  text,
  boolean,
  timestamp,
  primaryKey,
} from 'drizzle-orm/pg-core'

import { profile, topic } from './identity.ts'

export const activityState = pgEnum('activity_state', ['idea', 'confirmed'])
export const activityScope = pgEnum('activity_scope', ['friends', 'squad'])
export const audienceKind = pgEnum('audience_kind', ['all_friends', 'people'])
export const optionKind = pgEnum('option_kind', ['time', 'location'])
export const responseValue = pgEnum('response_value', [
  'in',
  'interested',
  'next_time',
])

// The central two-state record: an `idea` while tentative, a `confirmed` activity
// once the captain locks a time + place — two states of one row. See
// specs/behaviors/ideas-activities-lifecycle.md.
//
// Stage 2 wires friends scope + all_friends/people audience. `squad_id` and
// `community_event_id` columns exist for later stages but are unused (no FK yet —
// the squad/community tables don't exist). `confirmed_*_option_id` are plain uuids
// (no FK) to avoid a circular activity↔activity_option constraint; integrity is
// enforced in the domain layer.
export const activity = pgTable('activity', {
  id: uuid('id').primaryKey().defaultRandom(),
  captainId: uuid('captain_id')
    .notNull()
    .references(() => profile.id, { onDelete: 'cascade' }),
  activityTypeId: uuid('activity_type_id')
    .notNull()
    .references(() => topic.id),
  state: activityState('state').notNull().default('idea'),
  scope: activityScope('scope').notNull().default('friends'),
  squadId: uuid('squad_id'),
  audienceKind: audienceKind('audience_kind').notNull().default('all_friends'),
  allowSuggestions: boolean('allow_suggestions').notNull().default(false),
  confirmedTimeOptionId: uuid('confirmed_time_option_id'),
  confirmedLocationOptionId: uuid('confirmed_location_option_id'),
  communityEventId: uuid('community_event_id'),
  createdAt: timestamp('created_at', { withTimezone: true })
    .notNull()
    .defaultNow(),
  confirmedAt: timestamp('confirmed_at', { withTimezone: true }),
})

// Proposed time/location options on an activity.
export const activityOption = pgTable('activity_option', {
  id: uuid('id').primaryKey().defaultRandom(),
  activityId: uuid('activity_id')
    .notNull()
    .references(() => activity.id, { onDelete: 'cascade' }),
  kind: optionKind('kind').notNull(),
  label: text('label').notNull(),
  createdBy: uuid('created_by')
    .notNull()
    .references(() => profile.id, { onDelete: 'cascade' }),
})

// Who voted for which option.
export const optionVote = pgTable(
  'option_vote',
  {
    optionId: uuid('option_id')
      .notNull()
      .references(() => activityOption.id, { onDelete: 'cascade' }),
    profileId: uuid('profile_id')
      .notNull()
      .references(() => profile.id, { onDelete: 'cascade' }),
  },
  (t) => [primaryKey({ columns: [t.optionId, t.profileId] })],
)

// A participant's inline response. Absence = passive dismiss (no decline value).
export const response = pgTable(
  'response',
  {
    activityId: uuid('activity_id')
      .notNull()
      .references(() => activity.id, { onDelete: 'cascade' }),
    profileId: uuid('profile_id')
      .notNull()
      .references(() => profile.id, { onDelete: 'cascade' }),
    value: responseValue('value').notNull(),
  },
  (t) => [primaryKey({ columns: [t.activityId, t.profileId] })],
)

// Recipients when audience_kind = people (empty for all_friends).
export const activityAudience = pgTable(
  'activity_audience',
  {
    activityId: uuid('activity_id')
      .notNull()
      .references(() => activity.id, { onDelete: 'cascade' }),
    profileId: uuid('profile_id')
      .notNull()
      .references(() => profile.id, { onDelete: 'cascade' }),
  },
  (t) => [primaryKey({ columns: [t.activityId, t.profileId] })],
)
