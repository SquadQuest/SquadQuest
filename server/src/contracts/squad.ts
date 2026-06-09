import type { SquadSummary, SquadDetail } from '../domain/squad/service.ts'

// Squad wire shapes. See specs/screens/squads.md + data-model.md.
export function serializeSquadSummary(s: SquadSummary) {
  return {
    id: s.squad.id,
    name: s.squad.name,
    role: s.role,
    member_count: s.memberCount,
    created_at: s.squad.createdAt.toISOString(),
  }
}

export function serializeSquadDetail(d: SquadDetail) {
  return {
    id: d.squad.id,
    name: d.squad.name,
    created_at: d.squad.createdAt.toISOString(),
    members: d.members.map((m) => ({
      id: m.profile.id,
      first_name: m.profile.firstName,
      photo: m.profile.photo,
      role: m.role,
    })),
  }
}
