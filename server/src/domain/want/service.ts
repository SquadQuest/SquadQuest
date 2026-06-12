import { and, desc, eq, inArray, isNull, isNotNull } from 'drizzle-orm'

import type { Database } from '../../db/index.ts'
import { want, wantInvite, activity, topic } from '../../db/schema/index.ts'
import { ApiError, errors } from '../../contracts/errors.ts'
import { ActivityService, type CreateIdeaInput } from '../activity/service.ts'

type WantRow = typeof want.$inferSelect
type InviteRow = typeof wantInvite.$inferSelect
type ResponseValue = 'in' | 'interested' | 'next_time'

export interface CreateWantInput {
  activityTypeId: string
  title?: string | null
  location?: string | null
  notes?: string | null
  kind?: 'one_shot' | 'ongoing'
  inviteeIds?: string[]
}

export interface WantView {
  want: WantRow
  invites: InviteRow[]
}

export class WantService {
  constructor(private readonly db: Database) {}

  private get activities() {
    return new ActivityService(this.db)
  }

  private async assertTopic(activityTypeId: string): Promise<void> {
    const [t] = await this.db.select().from(topic).where(eq(topic.id, activityTypeId))
    if (!t) throw errors.badRequest('topic_invalid', 'Unknown activity type')
  }

  // Restrict invitees to accepted friends of the owner (the only way a want reaches anyone).
  private async assertFriends(ownerId: string, ids: string[]): Promise<void> {
    if (ids.length === 0) return
    const friends = new Set(await this.activities.acceptedFriendIds(ownerId))
    for (const id of ids) {
      if (!friends.has(id)) {
        throw errors.badRequest('not_a_friend', 'Can only invite accepted friends')
      }
    }
  }

  private async invitesFor(wantId: string): Promise<InviteRow[]> {
    return this.db.select().from(wantInvite).where(eq(wantInvite.wantId, wantId))
  }

  private async ownedOr404(ownerId: string, wantId: string): Promise<WantRow> {
    const [w] = await this.db.select().from(want).where(eq(want.id, wantId))
    if (!w || w.ownerId !== ownerId) {
      // Don't distinguish "not found" from "not yours".
      throw new ApiError(404, 'not_found', 'Want not found')
    }
    return w
  }

  private async view(wantId: string): Promise<WantView> {
    const [w] = await this.db.select().from(want).where(eq(want.id, wantId))
    if (!w) throw new ApiError(404, 'not_found', 'Want not found')
    return { want: w, invites: await this.invitesFor(wantId) }
  }

  // The caller's own wants (active by default).
  async listOwn(ownerId: string, includeArchived = false): Promise<WantView[]> {
    const rows = await this.db
      .select()
      .from(want)
      .where(
        includeArchived
          ? eq(want.ownerId, ownerId)
          : and(eq(want.ownerId, ownerId), isNull(want.archivedAt)),
      )
      .orderBy(desc(want.createdAt))
    if (rows.length === 0) return []
    const ids = rows.map((r) => r.id)
    const allInvites = await this.db
      .select()
      .from(wantInvite)
      .where(inArray(wantInvite.wantId, ids))
    return rows.map((w) => ({
      want: w,
      invites: allInvites.filter((i) => i.wantId === w.id),
    }))
  }

  // Wants the caller is invited to (not ignored, not archived).
  async listInvited(viewerId: string): Promise<WantView[]> {
    const invites = await this.db
      .select()
      .from(wantInvite)
      .where(and(eq(wantInvite.profileId, viewerId), isNull(wantInvite.ignoredAt)))
    if (invites.length === 0) return []
    const wantIds = invites.map((i) => i.wantId)
    const rows = await this.db
      .select()
      .from(want)
      .where(and(inArray(want.id, wantIds), isNull(want.archivedAt)))
      .orderBy(desc(want.createdAt))
    if (rows.length === 0) return []
    const ids = rows.map((r) => r.id)
    const allInvites = await this.db
      .select()
      .from(wantInvite)
      .where(inArray(wantInvite.wantId, ids))
    return rows.map((w) => ({
      want: w,
      invites: allInvites.filter((i) => i.wantId === w.id),
    }))
  }

  // Wants the caller has ignored (for the Ignored recovery surface).
  async listIgnored(viewerId: string): Promise<WantView[]> {
    const invites = await this.db
      .select()
      .from(wantInvite)
      .where(and(eq(wantInvite.profileId, viewerId), isNotNull(wantInvite.ignoredAt)))
    if (invites.length === 0) return []
    const wantIds = invites.map((i) => i.wantId)
    const rows = await this.db.select().from(want).where(inArray(want.id, wantIds))
    return Promise.all(rows.map((w) => this.view(w.id)))
  }

  async create(ownerId: string, input: CreateWantInput): Promise<WantView> {
    await this.assertTopic(input.activityTypeId)
    const inviteeIds = [...new Set(input.inviteeIds ?? [])].filter((id) => id !== ownerId)
    await this.assertFriends(ownerId, inviteeIds)
    return this.db.transaction(async (tx) => {
      const [w] = await tx
        .insert(want)
        .values({
          ownerId,
          activityTypeId: input.activityTypeId,
          title: input.title ?? null,
          location: input.location ?? null,
          notes: input.notes ?? null,
          kind: input.kind ?? 'one_shot',
        })
        .returning()
      if (inviteeIds.length) {
        await tx
          .insert(wantInvite)
          .values(inviteeIds.map((profileId) => ({ wantId: w!.id, profileId })))
      }
      const invites = await tx.select().from(wantInvite).where(eq(wantInvite.wantId, w!.id))
      return { want: w!, invites }
    })
  }

  async update(
    ownerId: string,
    wantId: string,
    patch: {
      activityTypeId?: string
      title?: string | null
      location?: string | null
      notes?: string | null
      kind?: 'one_shot' | 'ongoing'
    },
  ): Promise<WantView> {
    await this.ownedOr404(ownerId, wantId)
    if (patch.activityTypeId) await this.assertTopic(patch.activityTypeId)
    const set: Record<string, unknown> = {}
    if (patch.activityTypeId !== undefined) set.activityTypeId = patch.activityTypeId
    if (patch.title !== undefined) set.title = patch.title
    if (patch.location !== undefined) set.location = patch.location
    if (patch.notes !== undefined) set.notes = patch.notes
    if (patch.kind !== undefined) set.kind = patch.kind
    if (Object.keys(set).length) {
      set.updatedAt = new Date()
      await this.db.update(want).set(set).where(eq(want.id, wantId))
    }
    return this.view(wantId)
  }

  async remove(ownerId: string, wantId: string): Promise<void> {
    await this.ownedOr404(ownerId, wantId)
    await this.db.delete(want).where(eq(want.id, wantId))
  }

  // Invite accepted friends (idempotent per friend). Owner only.
  async invite(ownerId: string, wantId: string, profileIds: string[]): Promise<WantView> {
    await this.ownedOr404(ownerId, wantId)
    const ids = [...new Set(profileIds)].filter((id) => id !== ownerId)
    await this.assertFriends(ownerId, ids)
    if (ids.length) {
      await this.db
        .insert(wantInvite)
        .values(ids.map((profileId) => ({ wantId, profileId })))
        .onConflictDoNothing()
    }
    return this.view(wantId)
  }

  async uninvite(ownerId: string, wantId: string, profileId: string): Promise<WantView> {
    await this.ownedOr404(ownerId, wantId)
    await this.db
      .delete(wantInvite)
      .where(and(eq(wantInvite.wantId, wantId), eq(wantInvite.profileId, profileId)))
    return this.view(wantId)
  }

  // Invitee sets/clears their soft response. Caller must be an invitee.
  private async assertInvitee(viewerId: string, wantId: string): Promise<void> {
    const [inv] = await this.db
      .select()
      .from(wantInvite)
      .where(and(eq(wantInvite.wantId, wantId), eq(wantInvite.profileId, viewerId)))
    if (!inv) throw new ApiError(404, 'not_found', 'Want not found')
  }

  async respond(viewerId: string, wantId: string, value: ResponseValue): Promise<WantView> {
    await this.assertInvitee(viewerId, wantId)
    await this.db
      .update(wantInvite)
      .set({ response: value })
      .where(and(eq(wantInvite.wantId, wantId), eq(wantInvite.profileId, viewerId)))
    return this.view(wantId)
  }

  async clearResponse(viewerId: string, wantId: string): Promise<WantView> {
    await this.assertInvitee(viewerId, wantId)
    await this.db
      .update(wantInvite)
      .set({ response: null })
      .where(and(eq(wantInvite.wantId, wantId), eq(wantInvite.profileId, viewerId)))
    return this.view(wantId)
  }

  // Ignore / un-ignore an invite (silent + recoverable; never surfaced to the owner).
  async setIgnored(viewerId: string, wantId: string, ignored: boolean): Promise<void> {
    await this.assertInvitee(viewerId, wantId)
    await this.db
      .update(wantInvite)
      .set({ ignoredAt: ignored ? new Date() : null })
      .where(and(eq(wantInvite.wantId, wantId), eq(wantInvite.profileId, viewerId)))
  }

  // Promote = spawn a real idea via the existing create path. Owner only. Audience
  // defaults to the want's invitees (people scope) when none is given. one_shot
  // archives; ongoing stays. Returns the new activity id.
  async promote(
    ownerId: string,
    wantId: string,
    overrides: Partial<CreateIdeaInput> & { audience?: CreateIdeaInput['audience'] },
  ): Promise<string> {
    const w = await this.ownedOr404(ownerId, wantId)
    if (w.archivedAt) throw new ApiError(409, 'want_archived', 'Want already promoted')

    let audience = overrides.audience
    if (!audience && (!overrides.scope || overrides.scope === 'friends')) {
      const invitees = (await this.invitesFor(wantId)).map((i) => i.profileId)
      audience = invitees.length
        ? { kind: 'people', personIds: invitees }
        : { kind: 'all_friends' }
    }

    const activityId = await this.activities.createIdea(ownerId, {
      activityTypeId: w.activityTypeId,
      scope: overrides.scope,
      squadId: overrides.squadId,
      audience: audience ?? { kind: 'all_friends' },
      allowSuggestions: overrides.allowSuggestions,
      timeOptions: overrides.timeOptions,
      locationOptions: overrides.locationOptions,
      communityEventId: overrides.communityEventId,
    })

    await this.db.update(activity).set({ fromWantId: wantId }).where(eq(activity.id, activityId))
    if (w.kind === 'one_shot') {
      await this.db.update(want).set({ archivedAt: new Date() }).where(eq(want.id, wantId))
    }
    return activityId
  }
}
