import { asc, desc, eq, ilike, sql } from 'drizzle-orm'

import type { Database } from '../../db/index.ts'
import { topic } from '../../db/schema/index.ts'
import { errors } from '../../contracts/errors.ts'

type TopicRow = typeof topic.$inferSelect

// Normalize a label for dedup: lowercase, trim, collapse internal whitespace,
// strip surrounding punctuation. "  Hiking! " and "hiking" → "hiking". The only
// create-time dedup (fuzzy/semantic merge is v2-activity-types-merge).
export function normalizeLabel(label: string): string {
  return label
    .trim()
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .replace(/^[\p{P}\s]+|[\p{P}\s]+$/gu, '')
}

export class TopicService {
  constructor(private readonly db: Database) {}

  // Official-first list (official before community, then alphabetical), with an
  // optional normalized substring search on the label.
  async list(search?: string): Promise<TopicRow[]> {
    const term = search?.trim()
    return this.db
      .select()
      .from(topic)
      .where(term ? ilike(topic.label, `%${term}%`) : undefined)
      .orderBy(
        // official (kind = 'official') first, then label A→Z.
        desc(sql`(${topic.kind} = 'official')`),
        asc(topic.label),
      )
  }

  // Resolve a free-text label to a topic: reuse an existing one whose normalized
  // label matches (official or community), else insert a new community topic. The
  // single source of truth for both the dedicated create and the on-the-fly path.
  async findOrCreate(
    rawLabel: string,
    createdBy: string,
  ): Promise<{ topic: TopicRow; created: boolean }> {
    const label = rawLabel.trim()
    if (!label) throw errors.badRequest('label_required', 'A label is required')
    const norm = normalizeLabel(label)

    // Compare against the normalized form of existing labels.
    const [existing] = await this.db
      .select()
      .from(topic)
      .where(eq(sql`lower(regexp_replace(btrim(${topic.label}), '\\s+', ' ', 'g'))`, norm))
      .limit(1)
    if (existing) return { topic: existing, created: false }

    // New community type. noun/verb derive from the label (label is the source of
    // truth for community types — no noun-verb form). noun = the label, verb = ''.
    const [row] = await this.db
      .insert(topic)
      .values({ noun: label, verb: '', label, kind: 'community', createdBy })
      .returning()
    return { topic: row!, created: true }
  }

  // Resolve an idea/want's activity type from either an id or a free-text label
  // (exactly one). Returns the topic id to store. Backward-compatible: id-only
  // callers are unaffected.
  async resolveActivityType(
    input: { activityTypeId?: string; activityTypeLabel?: string },
    createdBy: string,
  ): Promise<string> {
    if (input.activityTypeId) {
      const [t] = await this.db.select().from(topic).where(eq(topic.id, input.activityTypeId))
      if (!t) throw errors.badRequest('topic_invalid', 'Unknown activity type')
      return t.id
    }
    if (input.activityTypeLabel) {
      const { topic: t } = await this.findOrCreate(input.activityTypeLabel, createdBy)
      return t.id
    }
    throw errors.badRequest('topic_required', 'An activity type id or label is required')
  }
}
