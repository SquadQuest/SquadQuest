import { and, eq, isNotNull, or } from 'drizzle-orm'

import type { Database } from '../../db/index.ts'
import { profile, friendship } from '../../db/schema/index.ts'
import { ApiError, errors } from '../../contracts/errors.ts'
import { normalizePhone } from '../auth/phone.ts'

type ProfileRow = typeof profile.$inferSelect

export interface FriendRequestView {
  id: string
  profile: ProfileRow // the *other* party (sender for incoming, target for outgoing)
  createdAt: Date
}

// The double-opt-in friend graph: send-by-phone requests, accept/decline.
// See specs/behaviors/friend-connections.md + specs/api/friends.md.
export class FriendService {
  constructor(private readonly db: Database) {}

  // Send a connection request by phone. Resolves the phone to a profile (creating
  // an unclaimed shell if none — same mechanism as v1 migration), then applies the
  // one-edge-per-pair / idempotent / auto-accept rules. Returns the resulting status.
  async requestByPhone(me: string, rawPhone: string): Promise<'requested' | 'accepted'> {
    const phone = normalizePhone(rawPhone)

    let [target] = await this.db.select().from(profile).where(eq(profile.phone, phone))
    if (target && target.id === me) {
      throw errors.badRequest('cannot_self_request', 'You cannot friend yourself')
    }
    if (!target) {
      // Unclaimed shell — the pending request waits until they claim on login.
      const [created] = await this.db.insert(profile).values({ phone }).returning()
      target = created!
    }
    const targetId = target.id

    // The single edge for this unordered pair, in either direction.
    const [edge] = await this.db
      .select()
      .from(friendship)
      .where(
        or(
          and(eq(friendship.requester, me), eq(friendship.requestee, targetId)),
          and(eq(friendship.requester, targetId), eq(friendship.requestee, me)),
        ),
      )

    if (edge) {
      if (edge.status === 'accepted') return 'accepted'
      // status === 'requested' (the only other value).
      if (edge.requester === targetId) {
        // They already requested me → my "send" is an accept. (If I'd ignored
        // their request, accepting supersedes the ignore.)
        await this.db
          .update(friendship)
          .set({ status: 'accepted', ignoredAt: null })
          .where(eq(friendship.id, edge.id))
        return 'accepted'
      }
      return 'requested' // I already requested them — idempotent.
    }

    await this.db
      .insert(friendship)
      .values({ requester: me, requestee: targetId, status: 'requested' })
    return 'requested'
  }

  // Pending requests involving the caller, split by direction. `profile` on each
  // view is the *other* party — never the caller.
  async listRequests(
    me: string,
  ): Promise<{ incoming: FriendRequestView[]; outgoing: FriendRequestView[] }> {
    const edges = await this.db
      .select()
      .from(friendship)
      .where(
        and(
          eq(friendship.status, 'requested'),
          or(eq(friendship.requester, me), eq(friendship.requestee, me)),
        ),
      )
    if (edges.length === 0) return { incoming: [], outgoing: [] }

    const otherIds = edges.map((e) => (e.requester === me ? e.requestee : e.requester))
    const profiles = await this.db
      .select()
      .from(profile)
      .where(or(...otherIds.map((id) => eq(profile.id, id))))
    const byId = new Map(profiles.map((p) => [p.id, p]))

    const incoming: FriendRequestView[] = []
    const outgoing: FriendRequestView[] = []
    for (const e of edges) {
      const otherId = e.requester === me ? e.requestee : e.requester
      const other = byId.get(otherId)
      if (!other) continue
      const view = { id: e.id, profile: other, createdAt: e.createdAt }
      if (e.requestee === me) {
        // Ignored incoming requests leave this list for the Ignored surface; the
        // sender's outgoing view is unaffected by whether the recipient ignored.
        if (e.ignoredAt === null) incoming.push(view)
      } else {
        outgoing.push(view)
      }
    }
    return { incoming, outgoing }
  }

  // Incoming requests the caller has ignored (for the Ignored recovery surface).
  async listIgnoredRequests(me: string): Promise<FriendRequestView[]> {
    const edges = await this.db
      .select()
      .from(friendship)
      .where(
        and(
          eq(friendship.status, 'requested'),
          eq(friendship.requestee, me),
          isNotNull(friendship.ignoredAt),
        ),
      )
    if (edges.length === 0) return []
    const senderIds = edges.map((e) => e.requester)
    const senders = await this.db
      .select()
      .from(profile)
      .where(or(...senderIds.map((id) => eq(profile.id, id))))
    const byId = new Map(senders.map((p) => [p.id, p]))
    return edges
      .map((e) => {
        const other = byId.get(e.requester)
        return other ? { id: e.id, profile: other, createdAt: e.createdAt } : null
      })
      .filter((v): v is FriendRequestView => v !== null)
  }

  // Resolve an incoming `requested` edge owned by the caller (requestee). A
  // non-requestee / missing / accepted edge is indistinguishable from 404.
  private async incomingEdgeOr404(me: string, requestId: string) {
    const [edge] = await this.db
      .select()
      .from(friendship)
      .where(eq(friendship.id, requestId))
    if (!edge || edge.requestee !== me || edge.status !== 'requested') {
      throw new ApiError(404, 'not_found', 'Request not found')
    }
    return edge
  }

  // Accept an incoming request. Requestee-only. (There is no decline — see ignore.)
  async accept(me: string, requestId: string): Promise<'accepted'> {
    const edge = await this.incomingEdgeOr404(me, requestId)
    await this.db
      .update(friendship)
      .set({ status: 'accepted', ignoredAt: null })
      .where(eq(friendship.id, edge.id))
    return 'accepted'
  }

  // Ignore / un-ignore an incoming request. Silent (the edge stays `requested`, so
  // the sender still sees pending) and recoverable. Requestee-only.
  async setIgnored(me: string, requestId: string, ignored: boolean): Promise<void> {
    const edge = await this.incomingEdgeOr404(me, requestId)
    await this.db
      .update(friendship)
      .set({ ignoredAt: ignored ? new Date() : null })
      .where(eq(friendship.id, edge.id))
  }
}
