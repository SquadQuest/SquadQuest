import { pgTable, pgEnum, uuid, text, timestamp } from 'drizzle-orm/pg-core'

import { profile } from './identity.ts'
import { squad } from './squad.ts'

// Polymorphic thread root kinds (specs/data-model.md). community_event arrives with
// the communities stage.
export const threadTargetType = pgEnum('thread_target_type', [
  'activity',
  'community_event',
  'message',
])

// Free-text + photo posts — covers squad top-level messages AND thread replies
// (one primitive). Exactly one context: squad (top-level squad post) XOR thread_of
// (thread reply), enforced in the domain layer. Attachments arrive with storage.
export const message = pgTable('message', {
  id: uuid('id').primaryKey().defaultRandom(),
  senderId: uuid('sender_id')
    .notNull()
    .references(() => profile.id, { onDelete: 'cascade' }),
  body: text('body'), // nullable ⇒ photo-only (once attachments land)
  // top-level squad message:
  squadId: uuid('squad_id').references(() => squad.id, { onDelete: 'cascade' }),
  // thread reply (polymorphic root):
  threadTargetType: threadTargetType('thread_target_type'),
  threadTargetId: uuid('thread_target_id'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
})
