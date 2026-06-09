import { inArray } from 'drizzle-orm'

import type { Database } from '../db/index.ts'
import { message, profile } from '../db/schema/index.ts'
import { MessageService } from '../domain/message/service.ts'

type MessageRow = typeof message.$inferSelect

// Batched message serializer (specs/api/messages.md). thread_count = replies when
// this message is itself a thread root. attachments are [] until storage lands.
export async function serializeMessages(db: Database, rows: MessageRow[]) {
  if (rows.length === 0) return []
  const senderIds = [...new Set(rows.map((r) => r.senderId))]
  const senders = await db.select().from(profile).where(inArray(profile.id, senderIds))
  const senderById = new Map(senders.map((s) => [s.id, s]))

  const counts = await new MessageService(db).threadCounts(
    'message',
    rows.map((r) => r.id),
  )

  return rows.map((r) => {
    const s = senderById.get(r.senderId)
    return {
      id: r.id,
      sender: s ? { id: s.id, first_name: s.firstName, photo: s.photo } : null,
      body: r.body,
      attachments: [] as { key: string; url: string }[],
      thread_count: counts.get(r.id) ?? 0,
      created_at: r.createdAt.toISOString(),
    }
  })
}

export async function serializeMessage(db: Database, row: MessageRow) {
  const [one] = await serializeMessages(db, [row])
  return one
}
