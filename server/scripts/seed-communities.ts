// Dev seed for communities + events. Leader tooling (creating communities/events)
// is deferred, so this stands in for what leaders will eventually do — for local
// testing/demo only. Idempotent by community name.
//
//   DATABASE_URL=... bun scripts/seed-communities.ts
import postgres from 'postgres'

const sql = postgres(process.env.DATABASE_URL!)

const COMMUNITIES = [
  {
    name: 'Wednesday Night Rides',
    tagline: 'Casual group rides every Wednesday',
    icon: '🚲',
    color: '#6750A4',
    events: [
      { title: 'Cherry Blossoms Ride', time: 'Wed Apr 1 · 6:30pm', recurrence: 'Every other Wed', location: 'Clark Park → Kelly Drive · 10.2mi · Easy' },
      { title: 'Sunset Loop', time: 'Wed Apr 8 · 6:30pm', recurrence: 'Every Wed', location: 'Lloyd Hall · 14mi · Moderate' },
    ],
  },
  {
    name: 'Black Squirrel Club',
    tagline: 'Trail running + social',
    icon: '🐿️',
    color: '#2E7D32',
    events: [
      { title: 'Wissahickon Trail Run', time: 'Sat Apr 4 · 8:00am', recurrence: 'Every Sat', location: 'Valley Green Inn · 6mi · Moderate' },
    ],
  },
  {
    name: 'Philly River Flow',
    tagline: 'Stand-up paddleboarding on the Schuylkill',
    icon: '🌊',
    color: '#0277BD',
    events: [
      { title: 'Morning Paddle', time: 'Sun Apr 5 · 9:00am', recurrence: 'Every Sun', location: 'Bartram’s Garden Dock · Flatwater' },
    ],
  },
]

for (const c of COMMUNITIES) {
  const [existing] = await sql<{ id: string }[]>`select id from community where name = ${c.name}`
  const id =
    existing?.id ??
    (
      await sql<{ id: string }[]>`
        insert into community (name, tagline, icon, color)
        values (${c.name}, ${c.tagline}, ${c.icon}, ${c.color}) returning id`
    )[0].id

  for (const e of c.events) {
    const [ev] = await sql`select id from community_event where community_id = ${id} and title = ${e.title}`
    if (!ev) {
      await sql`
        insert into community_event (community_id, title, time, recurrence, location)
        values (${id}, ${e.title}, ${e.time}, ${e.recurrence}, ${e.location})`
    }
  }
  console.log(`✓ ${c.name} (${c.events.length} events)`)
}

await sql.end()
console.log('seeded communities')
