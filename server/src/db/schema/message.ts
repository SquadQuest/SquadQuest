import { pgTable, pgEnum, uuid, text, timestamp, jsonb } from 'drizzle-orm/pg-core'

import { profile } from './identity.ts'
import { squad } from './squad.ts'

// An image attachment on a message: the storage key + its public URL
// (specs/api/uploads.md). Stored as a jsonb array on the message.
export type MessageAttachment = { key: string; url: string }

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
  body: text('body'), // nullable ⇒ photo-only (body or attachments must be present)
  // image attachments (object-store keys + public URLs); defaults to empty.
  attachments: jsonb('attachments').$type<MessageAttachment[]>().notNull().default([]),
  // top-level squad message:
  squadId: uuid('squad_id').references(() => squad.id, { onDelete: 'cascade' }),
  // thread reply (polymorphic root):
  threadTargetType: threadTargetType('thread_target_type'),
  threadTargetId: uuid('thread_target_id'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
})
