import type { profile } from '../db/schema/index.ts'

type ProfileRow = typeof profile.$inferSelect

// Serialized profile wire shape (specs/api/auth.md). `photo` is a URL/key;
// signed-URL handling arrives with storage in a later stage.
export function serializeProfile(row: ProfileRow) {
  return {
    id: row.id,
    first_name: row.firstName,
    last_name: row.lastName,
    photo: row.photo,
    phone: row.phone,
    claimed_at: row.claimedAt ? row.claimedAt.toISOString() : null,
  }
}
