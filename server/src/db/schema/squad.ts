import { pgTable, pgEnum, uuid, text, timestamp, primaryKey } from 'drizzle-orm/pg-core'

import { profile } from './identity.ts'

export const squadRole = pgEnum('squad_role', ['captain', 'member'])

// Closed, persistent named groups — the evolution of the group text
// (specs/data-model.md). Captain controls membership; everyone may post.
export const squad = pgTable('squad', {
  id: uuid('id').primaryKey().defaultRandom(),
  name: text('name').notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
})

export const squadMembership = pgTable(
  'squad_membership',
  {
    squadId: uuid('squad_id')
      .notNull()
      .references(() => squad.id, { onDelete: 'cascade' }),
    profileId: uuid('profile_id')
      .notNull()
      .references(() => profile.id, { onDelete: 'cascade' }),
    role: squadRole('role').notNull().default('member'),
  },
  (t) => [primaryKey({ columns: [t.squadId, t.profileId] })],
)
