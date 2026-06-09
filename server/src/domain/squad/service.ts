import { and, eq, inArray, or } from 'drizzle-orm'

import type { Database } from '../../db/index.ts'
import { squad, squadMembership, friendship, profile } from '../../db/schema/index.ts'
import { ApiError, errors } from '../../contracts/errors.ts'

type SquadRow = typeof squad.$inferSelect
type ProfileRow = typeof profile.$inferSelect

export interface SquadSummary {
  squad: SquadRow
  role: 'captain' | 'member'
  memberCount: number
}

export interface SquadDetail {
  squad: SquadRow
  members: { profile: ProfileRow; role: 'captain' | 'member' }[]
}

export class SquadService {
  constructor(private readonly db: Database) {}

  private async acceptedFriendIds(profileId: string): Promise<string[]> {
    const edges = await this.db
      .select()
      .from(friendship)
      .where(
        and(
          eq(friendship.status, 'accepted'),
          or(eq(friendship.requester, profileId), eq(friendship.requestee, profileId)),
        ),
      )
    return edges.map((e) => (e.requester === profileId ? e.requestee : e.requester))
  }

  async isMember(squadId: string, profileId: string): Promise<boolean> {
    const [m] = await this.db
      .select()
      .from(squadMembership)
      .where(
        and(eq(squadMembership.squadId, squadId), eq(squadMembership.profileId, profileId)),
      )
    return Boolean(m)
  }

  // Create a squad; creator becomes captain. Optional initial members must be the
  // creator's accepted friends.
  async createSquad(
    creatorId: string,
    name: string,
    memberIds: string[] = [],
  ): Promise<string> {
    const trimmed = name.trim()
    if (!trimmed) throw errors.badRequest('name_required', 'Squad name is required')

    const friends = new Set(await this.acceptedFriendIds(creatorId))
    const members = [...new Set(memberIds)].filter((id) => id !== creatorId)
    const notFriends = members.filter((id) => !friends.has(id))
    if (notFriends.length) {
      throw errors.badRequest('not_friends', 'Members must be accepted friends')
    }

    return this.db.transaction(async (tx) => {
      const [created] = await tx.insert(squad).values({ name: trimmed }).returning({ id: squad.id })
      const squadId = created!.id
      await tx.insert(squadMembership).values({ squadId, profileId: creatorId, role: 'captain' })
      if (members.length) {
        await tx
          .insert(squadMembership)
          .values(members.map((profileId) => ({ squadId, profileId, role: 'member' as const })))
      }
      return squadId
    })
  }

  async listMySquads(profileId: string): Promise<SquadSummary[]> {
    const mine = await this.db
      .select({ squadId: squadMembership.squadId, role: squadMembership.role })
      .from(squadMembership)
      .where(eq(squadMembership.profileId, profileId))
    if (mine.length === 0) return []

    const ids = mine.map((m) => m.squadId)
    const squads = await this.db.select().from(squad).where(inArray(squad.id, ids))
    const allMembers = await this.db
      .select({ squadId: squadMembership.squadId })
      .from(squadMembership)
      .where(inArray(squadMembership.squadId, ids))

    const counts = new Map<string, number>()
    for (const m of allMembers) counts.set(m.squadId, (counts.get(m.squadId) ?? 0) + 1)
    const roleById = new Map(mine.map((m) => [m.squadId, m.role]))
    const squadById = new Map(squads.map((s) => [s.id, s]))

    return mine
      .map((m) => ({
        squad: squadById.get(m.squadId)!,
        role: roleById.get(m.squadId)!,
        memberCount: counts.get(m.squadId) ?? 0,
      }))
      .filter((s) => s.squad)
  }

  async getSquad(viewerId: string, squadId: string): Promise<SquadDetail> {
    if (!(await this.isMember(squadId, viewerId))) {
      throw new ApiError(404, 'not_found', 'Squad not found')
    }
    const [row] = await this.db.select().from(squad).where(eq(squad.id, squadId))
    if (!row) throw new ApiError(404, 'not_found', 'Squad not found')

    const rows = await this.db
      .select({ profile, role: squadMembership.role })
      .from(squadMembership)
      .innerJoin(profile, eq(profile.id, squadMembership.profileId))
      .where(eq(squadMembership.squadId, squadId))

    return { squad: row, members: rows.map((r) => ({ profile: r.profile, role: r.role })) }
  }

  async addMember(captainId: string, squadId: string, profileId: string): Promise<void> {
    const [me] = await this.db
      .select()
      .from(squadMembership)
      .where(
        and(eq(squadMembership.squadId, squadId), eq(squadMembership.profileId, captainId)),
      )
    if (!me) throw new ApiError(404, 'not_found', 'Squad not found')
    if (me.role !== 'captain') {
      throw errors.forbidden('not_captain', 'Only the captain can add members')
    }
    const friends = new Set(await this.acceptedFriendIds(captainId))
    if (!friends.has(profileId)) {
      throw errors.badRequest('not_friends', 'New members must be accepted friends')
    }
    await this.db
      .insert(squadMembership)
      .values({ squadId, profileId, role: 'member' })
      .onConflictDoNothing()
  }
}
