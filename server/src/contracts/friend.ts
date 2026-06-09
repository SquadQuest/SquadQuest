import type { profile } from '../db/schema/index.ts'

type ProfileRow = typeof profile.$inferSelect

// A friend as seen in lists. `on_v2` false = a carried friendship whose other
// party hasn't claimed their v2 profile yet ("not on v2 yet · invite"). See
// specs/behaviors/v1-migration.md.
export function serializeFriend(row: ProfileRow) {
  return {
    id: row.id,
    first_name: row.firstName,
    last_name: row.lastName,
    photo: row.photo,
    on_v2: row.claimedAt !== null,
  }
}
