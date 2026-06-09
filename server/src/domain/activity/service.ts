import { and, eq, inArray, or, sql } from 'drizzle-orm'

import type { Database } from '../../db/index.ts'
import {
  activity,
  activityOption,
  activityAudience,
  optionVote,
  response,
  friendship,
  topic,
  squadMembership,
} from '../../db/schema/index.ts'
import { ApiError, errors } from '../../contracts/errors.ts'

export interface CreateIdeaInput {
  activityTypeId: string
  scope?: 'friends' | 'squad'
  squadId?: string
  audience: { kind: 'all_friends' | 'people'; personIds?: string[] }
  allowSuggestions?: boolean
  timeOptions?: string[]
  locationOptions?: string[]
  communityEventId?: string
}

type ActivityRow = typeof activity.$inferSelect

export class ActivityService {
  constructor(private readonly db: Database) {}

  // Accepted friends of a profile (both directions of the double-opt-in graph).
  async acceptedFriendIds(profileId: string): Promise<string[]> {
    const edges = await this.db
      .select()
      .from(friendship)
      .where(
        and(
          eq(friendship.status, 'accepted'),
          or(
            eq(friendship.requester, profileId),
            eq(friendship.requestee, profileId),
          ),
        ),
      )
    return edges.map((e) => (e.requester === profileId ? e.requestee : e.requester))
  }

  async isSquadMember(squadId: string, profileId: string): Promise<boolean> {
    const [m] = await this.db
      .select()
      .from(squadMembership)
      .where(
        and(
          eq(squadMembership.squadId, squadId),
          eq(squadMembership.profileId, profileId),
        ),
      )
    return Boolean(m)
  }

  // Can `viewer` see this activity?
  // - squad scope: viewer is a member of the squad.
  // - friends scope: viewer is captain, or captain is an accepted friend AND
  //   (audience all_friends OR viewer is a named recipient).
  async canView(viewerId: string, act: ActivityRow): Promise<boolean> {
    if (act.scope === 'squad') {
      return act.squadId ? this.isSquadMember(act.squadId, viewerId) : false
    }
    if (act.captainId === viewerId) return true
    const friends = await this.acceptedFriendIds(viewerId)
    if (!friends.includes(act.captainId)) return false
    if (act.audienceKind === 'all_friends') return true
    const [aud] = await this.db
      .select()
      .from(activityAudience)
      .where(
        and(
          eq(activityAudience.activityId, act.id),
          eq(activityAudience.profileId, viewerId),
        ),
      )
    return Boolean(aud)
  }

  async getViewable(viewerId: string, activityId: string): Promise<ActivityRow> {
    const [act] = await this.db.select().from(activity).where(eq(activity.id, activityId))
    if (!act || !(await this.canView(viewerId, act))) {
      // Don't distinguish "not found" from "not allowed".
      throw new ApiError(404, 'not_found', 'Activity not found')
    }
    return act
  }

  // Create an idea (always starts in `idea` state). Supports friends scope
  // (all_friends / people audience) and squad scope (visible to squad members).
  async createIdea(captainId: string, input: CreateIdeaInput): Promise<string> {
    const scope = input.scope ?? 'friends'
    if (scope !== 'friends' && scope !== 'squad') {
      throw errors.badRequest('unsupported_scope', 'Unsupported scope')
    }
    if (input.communityEventId) {
      throw errors.badRequest('unsupported', 'Community events are not available yet')
    }
    if (scope === 'squad') {
      if (!input.squadId) {
        throw errors.badRequest('squad_required', 'squad scope requires squad_id')
      }
      if (!(await this.isSquadMember(input.squadId, captainId))) {
        throw errors.forbidden('not_a_member', 'You are not a member of this squad')
      }
    } else if (input.audience.kind === 'people' && !input.audience.personIds?.length) {
      throw errors.badRequest('audience_required', 'people audience requires person_ids')
    }

    const [type] = await this.db
      .select()
      .from(topic)
      .where(eq(topic.id, input.activityTypeId))
    if (!type) throw errors.badRequest('activity_type_invalid', 'Unknown activity type')

    const isSquad = scope === 'squad'
    return this.db.transaction(async (tx) => {
      const [created] = await tx
        .insert(activity)
        .values({
          captainId,
          activityTypeId: input.activityTypeId,
          state: 'idea',
          scope,
          squadId: isSquad ? input.squadId : null,
          // audience_kind is unused for squad scope (all members see it); store the
          // default so the NOT NULL column is satisfied.
          audienceKind: isSquad ? 'all_friends' : input.audience.kind,
          allowSuggestions: input.allowSuggestions ?? false,
        })
        .returning({ id: activity.id })
      const activityId = created!.id

      const options = [
        ...(input.timeOptions ?? []).map((label) => ({ kind: 'time' as const, label })),
        ...(input.locationOptions ?? []).map((label) => ({
          kind: 'location' as const,
          label,
        })),
      ]
      if (options.length) {
        await tx
          .insert(activityOption)
          .values(options.map((o) => ({ activityId, createdBy: captainId, ...o })))
      }

      if (!isSquad && input.audience.kind === 'people') {
        const ids = [...new Set(input.audience.personIds!)]
        await tx
          .insert(activityAudience)
          .values(ids.map((profileId) => ({ activityId, profileId })))
      }

      return activityId
    })
  }

  async setResponse(
    viewerId: string,
    activityId: string,
    value: 'in' | 'interested' | 'next_time',
  ): Promise<void> {
    await this.getViewable(viewerId, activityId)
    await this.db
      .insert(response)
      .values({ activityId, profileId: viewerId, value })
      .onConflictDoUpdate({
        target: [response.activityId, response.profileId],
        set: { value },
      })
  }

  async clearResponse(viewerId: string, activityId: string): Promise<void> {
    await this.getViewable(viewerId, activityId)
    await this.db
      .delete(response)
      .where(and(eq(response.activityId, activityId), eq(response.profileId, viewerId)))
  }

  async addOption(
    viewerId: string,
    activityId: string,
    kind: 'time' | 'location',
    label: string,
  ): Promise<void> {
    const act = await this.getViewable(viewerId, activityId)
    if (!act.allowSuggestions) {
      throw errors.forbidden('suggestions_disabled', 'Suggestions are not enabled')
    }
    await this.db.insert(activityOption).values({ activityId, kind, label, createdBy: viewerId })
  }

  async toggleVote(
    viewerId: string,
    activityId: string,
    optionId: string,
    voted: boolean,
  ): Promise<void> {
    await this.getViewable(viewerId, activityId)
    const [opt] = await this.db
      .select()
      .from(activityOption)
      .where(and(eq(activityOption.id, optionId), eq(activityOption.activityId, activityId)))
    if (!opt) throw errors.badRequest('option_invalid', 'Unknown option for this activity')

    if (voted) {
      await this.db
        .insert(optionVote)
        .values({ optionId, profileId: viewerId })
        .onConflictDoNothing()
    } else {
      await this.db
        .delete(optionVote)
        .where(and(eq(optionVote.optionId, optionId), eq(optionVote.profileId, viewerId)))
    }
  }

  // Captain locks time + place → promotes idea to confirmed activity (same row).
  async confirm(
    viewerId: string,
    activityId: string,
    input: { timeOptionId?: string; locationOptionId?: string },
  ): Promise<void> {
    const [act] = await this.db.select().from(activity).where(eq(activity.id, activityId))
    if (!act) throw new ApiError(404, 'not_found', 'Activity not found')
    if (act.captainId !== viewerId) throw errors.forbidden('not_captain', 'Only the captain can confirm')

    // Validate the chosen options belong to this activity and match kind.
    const validate = async (id: string | undefined, kind: 'time' | 'location') => {
      if (!id) return
      const [opt] = await this.db
        .select()
        .from(activityOption)
        .where(and(eq(activityOption.id, id), eq(activityOption.activityId, activityId)))
      if (!opt || opt.kind !== kind) {
        throw errors.badRequest('option_invalid', `Invalid ${kind} option`)
      }
    }
    await validate(input.timeOptionId, 'time')
    await validate(input.locationOptionId, 'location')

    await this.db
      .update(activity)
      .set({
        state: 'confirmed',
        confirmedTimeOptionId: input.timeOptionId ?? null,
        confirmedLocationOptionId: input.locationOptionId ?? null,
        confirmedAt: new Date(),
      })
      .where(eq(activity.id, activityId))
  }

  // The My Friends timeline: friends-scoped activities visible to the viewer,
  // newest first, cursor-paginated over (created_at, id).
  async friendsTimeline(
    viewerId: string,
    limit: number,
    before?: { createdAt: Date; id: string },
  ): Promise<ActivityRow[]> {
    const friendIds = [viewerId, ...(await this.acceptedFriendIds(viewerId))]

    const visible = or(
      eq(activity.audienceKind, 'all_friends'),
      eq(activity.captainId, viewerId),
      sql`exists (select 1 from ${activityAudience} aa where aa.activity_id = ${activity.id} and aa.profile_id = ${viewerId})`,
    )

    const cursor = before
      ? sql`(${activity.createdAt}, ${activity.id}) < (${before.createdAt.toISOString()}, ${before.id})`
      : undefined

    return this.db
      .select()
      .from(activity)
      .where(
        and(
          eq(activity.scope, 'friends'),
          inArray(activity.captainId, friendIds),
          visible,
          ...(cursor ? [cursor] : []),
        ),
      )
      .orderBy(sql`${activity.createdAt} desc, ${activity.id} desc`)
      .limit(limit)
  }

  // A squad timeline: squad-scoped activities for one squad, newest first,
  // cursor-paginated. Membership must be checked by the caller (route).
  // (Free-text squad messages are interleaved here in a later stage.)
  async squadTimeline(
    squadId: string,
    limit: number,
    before?: { createdAt: Date; id: string },
  ): Promise<ActivityRow[]> {
    const cursor = before
      ? sql`(${activity.createdAt}, ${activity.id}) < (${before.createdAt.toISOString()}, ${before.id})`
      : undefined

    return this.db
      .select()
      .from(activity)
      .where(
        and(
          eq(activity.scope, 'squad'),
          eq(activity.squadId, squadId),
          ...(cursor ? [cursor] : []),
        ),
      )
      .orderBy(sql`${activity.createdAt} desc, ${activity.id} desc`)
      .limit(limit)
  }
}
