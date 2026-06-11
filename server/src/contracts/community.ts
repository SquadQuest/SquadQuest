import type { CommunitySummary, EventView } from '../domain/community/service.ts'

// Community wire shapes (specs/api/communities.md).
export function serializeCommunity(s: CommunitySummary) {
  return {
    id: s.community.id,
    name: s.community.name,
    tagline: s.community.tagline,
    icon: s.community.icon,
    color: s.community.color,
    photo: s.community.photo,
    follower_count: s.followerCount,
    you_follow: s.youFollow,
    your_role: s.yourRole === 'leader' ? 'leader' : null,
  }
}

export function serializeCommunityEvent(
  v: EventView,
  community: { id: string; name: string; icon: string | null; color: string | null },
) {
  const c = v.event
  return {
    id: c.id,
    community: {
      id: community.id,
      name: community.name,
      icon: community.icon,
      color: community.color,
    },
    title: c.title,
    activity_type: v.activityTypeLabel
      ? { id: c.activityTypeId, label: v.activityTypeLabel }
      : null,
    time: c.time,
    recurrence: c.recurrence,
    location: c.location,
    going_count: v.goingCount,
    public_going: v.publicGoing.map((p) => ({
      id: p.id,
      first_name: p.firstName,
      photo: p.photo,
    })),
    your_rsvp: v.yourRsvp,
    thread_count: v.threadCount,
  }
}
