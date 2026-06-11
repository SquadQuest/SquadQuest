import { and, eq, inArray, sql } from 'drizzle-orm'

import type { Database } from '../../db/index.ts'
import { message, activity, communityEvent } from '../../db/schema/index.ts'
import type { MessageAttachment } from '../../db/schema/message.ts'
import { ApiError, errors } from '../../contracts/errors.ts'
import { ActivityService } from '../activity/service.ts'
import { SquadService } from '../squad/service.ts'

type MessageRow = typeof message.$inferSelect

// A message must carry text, image(s), or both — never be empty.
function assertHasContent(body: string, attachments: MessageAttachment[]): void {
  if (!body.trim() && attachments.length === 0) {
    throw errors.badRequest('empty_message', 'A message needs text or an attachment')
  }
}

// Polymorphic thread root kinds (specs/api/messages.md, data-model.md).
export type ThreadTargetType = 'activity' | 'community_event' | 'message'

export class MessageService {
  constructor(private readonly db: Database) {}

  private get activities() {
    return new ActivityService(this.db)
  }
  private get squads() {
    return new SquadService(this.db)
  }

  // Post a top-level message to a squad timeline (member-gated).
  async postSquadMessage(
    senderId: string,
    squadId: string,
    body: string,
    attachments: MessageAttachment[] = [],
  ): Promise<MessageRow> {
    assertHasContent(body, attachments)
    if (!(await this.squads.isMember(squadId, senderId))) {
      throw new ApiError(404, 'not_found', 'Squad not found')
    }
    const [row] = await this.db
      .insert(message)
      .values({ senderId, squadId, body: body.trim() || null, attachments })
      .returning()
    return row!
  }

  // Visibility for a thread target — reused for both reads and replies.
  // Returns the resolved target or throws 404 (indistinguishable from missing).
  private async assertCanSeeTarget(
    viewerId: string,
    targetType: ThreadTargetType,
    targetId: string,
  ): Promise<void> {
    if (targetType === 'activity') {
      const [act] = await this.db.select().from(activity).where(eq(activity.id, targetId))
      if (!act || !(await this.activities.canView(viewerId, act))) {
        throw new ApiError(404, 'not_found', 'Thread not found')
      }
      return
    }
    if (targetType === 'community_event') {
      // Communities are open: any authenticated user who can see the event (i.e. it
      // exists) can see its thread. No follow gate — mirrors the open events/discover read.
      const [ev] = await this.db
        .select()
        .from(communityEvent)
        .where(eq(communityEvent.id, targetId))
      if (!ev) throw new ApiError(404, 'not_found', 'Thread not found')
      return
    }
    // message target: a thread hung off a squad message → squad members can see it.
    const [msg] = await this.db.select().from(message).where(eq(message.id, targetId))
    if (!msg) throw new ApiError(404, 'not_found', 'Thread not found')
    const squadId = msg.squadId
    if (!squadId || !(await this.squads.isMember(squadId, viewerId))) {
      throw new ApiError(404, 'not_found', 'Thread not found')
    }
  }

  async threadMessages(
    viewerId: string,
    targetType: ThreadTargetType,
    targetId: string,
    limit: number,
    before?: { createdAt: Date; id: string },
  ): Promise<MessageRow[]> {
    await this.assertCanSeeTarget(viewerId, targetType, targetId)
    const cursor = before
      ? sql`(${message.createdAt}, ${message.id}) < (${before.createdAt.toISOString()}, ${before.id})`
      : undefined
    return this.db
      .select()
      .from(message)
      .where(
        and(
          eq(message.threadTargetType, targetType),
          eq(message.threadTargetId, targetId),
          ...(cursor ? [cursor] : []),
        ),
      )
      .orderBy(sql`${message.createdAt} desc, ${message.id} desc`)
      .limit(limit)
  }

  async postThreadReply(
    senderId: string,
    targetType: ThreadTargetType,
    targetId: string,
    body: string,
    attachments: MessageAttachment[] = [],
  ): Promise<MessageRow> {
    assertHasContent(body, attachments)
    await this.assertCanSeeTarget(senderId, targetType, targetId)
    const [row] = await this.db
      .insert(message)
      .values({
        senderId,
        threadTargetType: targetType,
        threadTargetId: targetId,
        body: body.trim() || null,
        attachments,
      })
      .returning()
    return row!
  }

  // Reply counts for a set of thread roots (batched), keyed by target id.
  async threadCounts(
    targetType: ThreadTargetType,
    targetIds: string[],
  ): Promise<Map<string, number>> {
    const counts = new Map<string, number>()
    if (targetIds.length === 0) return counts
    const rows = await this.db
      .select({ id: message.threadTargetId, n: sql<number>`count(*)::int` })
      .from(message)
      .where(
        and(
          eq(message.threadTargetType, targetType),
          inArray(message.threadTargetId, targetIds),
        ),
      )
      .groupBy(message.threadTargetId)
    for (const r of rows) if (r.id) counts.set(r.id, r.n)
    return counts
  }

  // Top-level messages for a squad timeline (merged with activities by the route).
  async squadMessages(
    squadId: string,
    limit: number,
    before?: { createdAt: Date; id: string },
  ): Promise<MessageRow[]> {
    const cursor = before
      ? sql`(${message.createdAt}, ${message.id}) < (${before.createdAt.toISOString()}, ${before.id})`
      : undefined
    return this.db
      .select()
      .from(message)
      .where(and(eq(message.squadId, squadId), ...(cursor ? [cursor] : [])))
      .orderBy(sql`${message.createdAt} desc, ${message.id} desc`)
      .limit(limit)
  }
}
