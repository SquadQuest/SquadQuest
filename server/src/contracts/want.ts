import { inArray } from 'drizzle-orm'

import type { Database } from '../db/index.ts'
import { profile, topic } from '../db/schema/index.ts'
import type { WantView } from '../domain/want/service.ts'

// Batched want serializer (specs/api/wants.md). `your_response` is set only when the
// caller is an invitee (not the owner); the owner sees the full invitee list with
// each invitee's response. Ignored invites are excluded from a want's invitee list in
// the owner's view? No — the owner sees all invites; an invitee ignoring is silent
// (ignoredAt is never serialized to anyone).
export async function serializeWants(db: Database, viewerId: string, views: WantView[]) {
  if (views.length === 0) return []

  const topicIds = [...new Set(views.map((v) => v.want.activityTypeId))]
  const profileIds = [
    ...new Set([
      ...views.map((v) => v.want.ownerId),
      ...views.flatMap((v) => v.invites.map((i) => i.profileId)),
    ]),
  ]
  const [topics, profiles] = await Promise.all([
    db.select().from(topic).where(inArray(topic.id, topicIds)),
    db.select().from(profile).where(inArray(profile.id, profileIds)),
  ])
  const topicById = new Map(topics.map((t) => [t.id, t]))
  const profById = new Map(profiles.map((p) => [p.id, p]))
  const mini = (id: string) => {
    const p = profById.get(id)
    return p ? { id: p.id, first_name: p.firstName, photo: p.photo } : null
  }

  return views.map(({ want: w, invites }) => {
    const t = topicById.get(w.activityTypeId)
    const mine = invites.find((i) => i.profileId === viewerId)
    return {
      id: w.id,
      owner: mini(w.ownerId),
      activity_type: t ? { id: t.id, label: t.label } : null,
      title: w.title,
      location: w.location,
      notes: w.notes,
      kind: w.kind,
      invitees: invites.map((i) => ({
        profile: mini(i.profileId),
        response: i.response,
      })),
      your_response: w.ownerId === viewerId ? undefined : (mine?.response ?? null),
      archived_at: w.archivedAt ? w.archivedAt.toISOString() : null,
      created_at: w.createdAt.toISOString(),
      updated_at: w.updatedAt.toISOString(),
    }
  })
}

export async function serializeWant(db: Database, viewerId: string, view: WantView) {
  const [s] = await serializeWants(db, viewerId, [view])
  return s
}
