import { inArray } from 'drizzle-orm'

import type { Database } from '../db/index.ts'
import {
  activity,
  activityOption,
  activityAudience,
  optionVote,
  response,
  profile,
  topic,
  squad,
} from '../db/schema/index.ts'

type ActivityRow = typeof activity.$inferSelect

// Batched assembler: serialize a page of activity rows into the wire shape
// (specs/api/ideas-activities.md) for `viewer`, loading options/votes/responses/
// captains/types in one pass each to avoid N+1. Output preserves input order.
export async function serializeActivities(
  db: Database,
  viewerId: string,
  rows: ActivityRow[],
) {
  if (rows.length === 0) return []

  const ids = rows.map((r) => r.id)
  const captainIds = [...new Set(rows.map((r) => r.captainId))]
  const typeIds = [...new Set(rows.map((r) => r.activityTypeId))]

  const [captains, types, options, audienceRows, responses] = await Promise.all([
    db.select().from(profile).where(inArray(profile.id, captainIds)),
    db.select().from(topic).where(inArray(topic.id, typeIds)),
    db.select().from(activityOption).where(inArray(activityOption.activityId, ids)),
    db.select().from(activityAudience).where(inArray(activityAudience.activityId, ids)),
    db.select().from(response).where(inArray(response.activityId, ids)),
  ])

  const optionIds = options.map((o) => o.id)
  const votes = optionIds.length
    ? await db.select().from(optionVote).where(inArray(optionVote.optionId, optionIds))
    : []

  // Squad names for squad-scoped rows (for the audience label).
  const squadIds = [...new Set(rows.map((r) => r.squadId).filter((id): id is string => !!id))]
  const squads = squadIds.length
    ? await db.select().from(squad).where(inArray(squad.id, squadIds))
    : []
  const squadNameById = new Map(squads.map((s) => [s.id, s.name]))

  const captainById = new Map(captains.map((c) => [c.id, c]))
  const typeById = new Map(types.map((t) => [t.id, t]))
  const optionById = new Map(options.map((o) => [o.id, o]))

  // votes per option + whether viewer voted
  const voteCount = new Map<string, number>()
  const youVoted = new Set<string>()
  for (const v of votes) {
    voteCount.set(v.optionId, (voteCount.get(v.optionId) ?? 0) + 1)
    if (v.profileId === viewerId) youVoted.add(v.optionId)
  }

  // responses per activity
  const respCounts = new Map<string, { in: number; interested: number }>()
  const yourResponse = new Map<string, string>()
  for (const r of responses) {
    const c = respCounts.get(r.activityId) ?? { in: 0, interested: 0 }
    if (r.value === 'in') c.in += 1
    else if (r.value === 'interested') c.interested += 1
    respCounts.set(r.activityId, c)
    if (r.profileId === viewerId) yourResponse.set(r.activityId, r.value)
  }

  // people-audience counts per activity
  const audienceCount = new Map<string, number>()
  for (const a of audienceRows) {
    audienceCount.set(a.activityId, (audienceCount.get(a.activityId) ?? 0) + 1)
  }

  const optionsByActivity = new Map<string, typeof options>()
  for (const o of options) {
    const list = optionsByActivity.get(o.activityId) ?? []
    list.push(o)
    optionsByActivity.set(o.activityId, list)
  }

  const serializeOption = (o: (typeof options)[number]) => ({
    id: o.id,
    label: o.label,
    votes: voteCount.get(o.id) ?? 0,
    you_voted: youVoted.has(o.id),
  })

  return rows.map((r) => {
    const captain = captainById.get(r.captainId)
    const type = typeById.get(r.activityTypeId)
    const opts = optionsByActivity.get(r.id) ?? []
    const counts = respCounts.get(r.id) ?? { in: 0, interested: 0 }

    // Audience label reflects scope: squad activities are visible to the whole
    // squad and only the squad (never "all friends"); friends activities use the
    // audience kind (all_friends / N people).
    const audience =
      r.scope === 'squad'
        ? {
            kind: 'squad',
            summary: r.squadId
                ? `${squadNameById.get(r.squadId) ?? 'Squad'} members`
                : 'Squad members',
          }
        : {
            kind: r.audienceKind,
            summary: r.audienceKind === 'all_friends'
                ? 'all friends'
                : `${audienceCount.get(r.id) ?? 0} ${
                    (audienceCount.get(r.id) ?? 0) === 1 ? 'person' : 'people'
                  }`,
          }

    return {
      id: r.id,
      state: r.state,
      captain: captain
        ? { id: captain.id, first_name: captain.firstName, photo: captain.photo }
        : null,
      activity_type: type ? { id: type.id, label: type.label } : null,
      scope: r.scope,
      squad_id: r.squadId,
      audience,
      allow_suggestions: r.allowSuggestions,
      time_options: opts.filter((o) => o.kind === 'time').map(serializeOption),
      location_options: opts.filter((o) => o.kind === 'location').map(serializeOption),
      confirmed_time: r.confirmedTimeOptionId
        ? (optionById.get(r.confirmedTimeOptionId)?.label ?? null)
        : null,
      confirmed_location: r.confirmedLocationOptionId
        ? (optionById.get(r.confirmedLocationOptionId)?.label ?? null)
        : null,
      your_response: yourResponse.get(r.id) ?? null,
      counts,
      thread_count: 0, // threads/messages arrive in a later stage
      event_ref: null, // bring-friends/community link arrives in a later stage
      created_at: r.createdAt.toISOString(),
    }
  })
}

export async function serializeActivity(
  db: Database,
  viewerId: string,
  row: ActivityRow,
) {
  const [one] = await serializeActivities(db, viewerId, [row])
  return one
}
