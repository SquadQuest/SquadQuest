import type { topic } from '../db/schema/index.ts'

type TopicRow = typeof topic.$inferSelect

// Serialized topic (activity type) wire shape. See specs/api/topics.md.
export function serializeTopic(row: TopicRow) {
  return {
    id: row.id,
    noun: row.noun,
    verb: row.verb,
    label: row.label,
    kind: row.kind,
    category: row.category,
  }
}
