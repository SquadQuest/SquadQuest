import { and, eq, ilike, inArray, sql } from 'drizzle-orm'

import type { Database } from '../../db/index.ts'
import {
  community,
  communityMembership,
  communityEvent,
  communityEventRsvp,
  topic,
  profile,
  message,
  activity,
  response,
} from '../../db/schema/index.ts'
import { ApiError } from '../../contracts/errors.ts'

type CommunityRow = typeof community.$inferSelect
type EventRow = typeof communityEvent.$inferSelect
type ProfileRow = typeof profile.$inferSelect

export interface CommunitySummary {
  community: CommunityRow
  followerCount: number
  youFollow: boolean
}

export interface EventView {
  event: EventRow
  activityTypeLabel: string | null
  goingCount: number
  publicGoing: ProfileRow[]
  yourRsvp: { going: boolean; public: boolean }
  threadCount: number
}

export class CommunityService {
  constructor(private readonly db: Database) {}

  async get(id: string): Promise<CommunityRow> {
    const [c] = await this.db.select().from(community).where(eq(community.id, id))
    if (!c) throw new ApiError(404, 'not_found', 'Community not found')
    return c
  }

  async discover(viewerId: string, search?: string): Promise<CommunitySummary[]> {
    const rows = await this.db
      .select()
      .from(community)
      .where(search ? ilike(community.name, `%${search}%`) : undefined)
      .orderBy(community.name)
    if (rows.length === 0) return []

    const ids = rows.map((r) => r.id)
    const memberships = await this.db
      .select()
      .from(communityMembership)
      .where(inArray(communityMembership.communityId, ids))

    const followerCount = new Map<string, number>()
    const youFollow = new Set<string>()
    for (const m of memberships) {
      followerCount.set(m.communityId, (followerCount.get(m.communityId) ?? 0) + 1)
      if (m.profileId === viewerId) youFollow.add(m.communityId)
    }
    return rows.map((c) => ({
      community: c,
      followerCount: followerCount.get(c.id) ?? 0,
      youFollow: youFollow.has(c.id),
    }))
  }

  async myCommunities(viewerId: string): Promise<CommunitySummary[]> {
    const mine = await this.db
      .select({ id: communityMembership.communityId })
      .from(communityMembership)
      .where(eq(communityMembership.profileId, viewerId))
    if (mine.length === 0) return []
    const all = await this.discover(viewerId)
    const ids = new Set(mine.map((m) => m.id))
    return all.filter((c) => ids.has(c.community.id))
  }

  async toggleFollow(
    viewerId: string,
    communityId: string,
    follow: boolean,
  ): Promise<{ youFollow: boolean; followerCount: number }> {
    const [c] = await this.db.select().from(community).where(eq(community.id, communityId))
    if (!c) throw new ApiError(404, 'not_found', 'Community not found')

    if (follow) {
      await this.db
        .insert(communityMembership)
        .values({ communityId, profileId: viewerId, role: 'follower' })
        .onConflictDoNothing()
    } else {
      await this.db
        .delete(communityMembership)
        .where(
          and(
            eq(communityMembership.communityId, communityId),
            eq(communityMembership.profileId, viewerId),
          ),
        )
    }
    const [{ count }] = await this.db
      .select({ count: sql<number>`count(*)::int` })
      .from(communityMembership)
      .where(eq(communityMembership.communityId, communityId))
    return { youFollow: follow, followerCount: count }
  }

  async events(viewerId: string, communityId: string): Promise<EventView[]> {
    const [c] = await this.db.select().from(community).where(eq(community.id, communityId))
    if (!c) throw new ApiError(404, 'not_found', 'Community not found')

    const evs = await this.db
      .select()
      .from(communityEvent)
      .where(eq(communityEvent.communityId, communityId))
      .orderBy(communityEvent.createdAt)
    if (evs.length === 0) return []

    const ids = evs.map((e) => e.id)
    const typeIds = [...new Set(evs.map((e) => e.activityTypeId).filter((x): x is string => !!x))]
    const [rsvps, types, threadRows] = await Promise.all([
      this.db.select().from(communityEventRsvp).where(inArray(communityEventRsvp.eventId, ids)),
      typeIds.length
        ? this.db.select().from(topic).where(inArray(topic.id, typeIds))
        : Promise.resolve([]),
      this.db
        .select({ id: message.threadTargetId, n: sql<number>`count(*)::int` })
        .from(message)
        .where(and(eq(message.threadTargetType, 'community_event'), inArray(message.threadTargetId, ids)))
        .groupBy(message.threadTargetId),
    ])

    // Bring-friends attendance coupling: a friend who responded "I'm in" to a
    // brought-along idea linked to this event is genuinely attending → counted in
    // the anonymous headcount, but NEVER added to the public face-pile.
    const broughtRows = await this.db
      .select({ eventId: activity.communityEventId, profileId: response.profileId })
      .from(response)
      .innerJoin(activity, eq(activity.id, response.activityId))
      .where(and(inArray(activity.communityEventId, ids), eq(response.value, 'in')))
    const broughtByEvent = new Map<string, Set<string>>()
    for (const r of broughtRows) {
      if (!r.eventId) continue
      ;(broughtByEvent.get(r.eventId) ?? broughtByEvent.set(r.eventId, new Set()).get(r.eventId)!)
        .add(r.profileId)
    }

    // public face-pile profiles
    const publicProfileIds = [...new Set(rsvps.filter((r) => r.public).map((r) => r.profileId))]
    const publicProfiles = publicProfileIds.length
      ? await this.db.select().from(profile).where(inArray(profile.id, publicProfileIds))
      : []
    const profileById = new Map(publicProfiles.map((p) => [p.id, p]))
    const typeById = new Map(types.map((t) => [t.id, t.label]))
    const threadById = new Map<string, number>()
    for (const t of threadRows) if (t.id) threadById.set(t.id, t.n)

    return evs.map((e) => {
      const evRsvps = rsvps.filter((r) => r.eventId === e.id)
      const mine = evRsvps.find((r) => r.profileId === viewerId)
      // distinct attendees: direct going RSVPs ∪ brought-along "in" responders
      const attendees = new Set<string>(broughtByEvent.get(e.id) ?? [])
      for (const r of evRsvps) if (r.going) attendees.add(r.profileId)
      return {
        event: e,
        activityTypeLabel: e.activityTypeId ? (typeById.get(e.activityTypeId) ?? null) : null,
        goingCount: attendees.size,
        publicGoing: evRsvps
          .filter((r) => r.public)
          .map((r) => profileById.get(r.profileId))
          .filter((p): p is ProfileRow => !!p),
        yourRsvp: { going: mine?.going ?? false, public: mine?.public ?? false },
        threadCount: threadById.get(e.id) ?? 0,
      }
    })
  }

  // Set the caller's attendance. public implies going; going:false clears both;
  // public is never set as a side effect.
  async setRsvp(
    viewerId: string,
    eventId: string,
    going: boolean,
    isPublic: boolean,
  ): Promise<EventView> {
    const [ev] = await this.db.select().from(communityEvent).where(eq(communityEvent.id, eventId))
    if (!ev) throw new ApiError(404, 'not_found', 'Event not found')

    const effectiveGoing = going || isPublic
    if (!effectiveGoing) {
      await this.db
        .delete(communityEventRsvp)
        .where(and(eq(communityEventRsvp.eventId, eventId), eq(communityEventRsvp.profileId, viewerId)))
    } else {
      await this.db
        .insert(communityEventRsvp)
        .values({ eventId, profileId: viewerId, going: true, public: isPublic })
        .onConflictDoUpdate({
          target: [communityEventRsvp.eventId, communityEventRsvp.profileId],
          set: { going: true, public: isPublic },
        })
    }
    const [view] = (await this.events(viewerId, ev.communityId)).filter((v) => v.event.id === eventId)
    return view!
  }
}
