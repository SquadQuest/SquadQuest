# Principles

SquadQuest v2's philosophy, written down as decisive rules. Each one picks a side of a
real trade-off so an implementer can resolve an unspecified case the way the project
would. Feature specs reference the entries that bite on them from their `## Principles`
sections.

## Private-first; public never touches the friends surface

The default surface — the **My Friends** timeline and its composer — only ever produces
**friends-scoped** content. Public exposure of a person or an event requires an *explicit*
action in a community context (or a public RSVP). The composer on My Friends can never
emit a public event.

> **Why.** v1 quietly let "public" be an event-visibility option in the same feed as
> everything else, which trained users to assume *posting = hosting a public event I'm
> responsible for*. That single blur killed the core vision. Public events return in v2
> only inside opt-in Communities, reached by an explicit context switch — the context
> switch *is* the firewall. Never let a friends-scoped action silently do a public-scoped
> thing.

## Lower the stakes of participation

When an interaction can be framed as a heavier commitment or a lighter one, choose lighter.
Posting an "idea" is lighter than "hosting an event"; "Interested" is lighter than an RSVP;
getting notified "Katie wants to go climbing" is lighter than "You're invited"; **not
responding is the dismiss** — there is no explicit decline button.

> **Why.** The whole point of v2 is to make casual hangouts actually happen. Friction and
> social risk at the moment of participation is what kills them. Default to the
> lower-pressure framing every time.

## Dismissal is silent and reversible

Anything one user sends another — a **friend request**, an event invite, a **want invite**, any
future incoming item — the recipient can **ignore**: it leaves their screens, and the result is
**indistinguishable to the sender from the recipient simply never having seen it**. There is no
"declined" / "rejected" state shown to the sender, ever. The sender's view of what they sent does
not change when the recipient ignores it (a pending request stays pending; an invite shows no
"declined" marker).

Ignoring is **reversible, never a black hole**: ignored items collect in an **Ignored** list
(see [`screens/ignored.md`](screens/ignored.md)) the user can browse to un-ignore something. So
"ignore" is safe to tap — it's *hide from me*, not *destroy*.

Use **one consistent vocabulary** across the whole app: the verb is **Ignore**, the recovered-items
surface is **Ignored**. Don't introduce synonyms ("dismiss", "decline", "reject", "hide") in UI
copy or API field names for this action.

> **Why.** This is [lower the stakes](#lower-the-stakes-of-participation) generalized from
> responses to *every* incoming thing. A visible "no" — even a soft one — creates social friction
> for both sides: the recipient feels rude declining, the sender feels rejected. Making dismissal
> silent removes that friction entirely; making it reversible removes the fear of an irreversible
> mistake. The existing "not responding is the dismiss" rule for idea/activity responses is one
> instance of this principle; friend requests and want invites are others.

## Group text, not social feed

Favor chat-like affordances — input at the bottom, scroll up for history, threads — over
infinite-scroll feed patterns. The home timeline is a place friends casually coordinate,
not content to consume.

## Audience clarity at the moment of action

Never leave a user uncertain who will see what they're about to post or how they respond.
Show the audience **at the point of action** (above the input, in the composer, in the
thread), not buried in settings.

> **Why.** Fear that something will be public or seen by people they don't know is the
> single biggest thing that holds people back from posting. Removing that uncertainty at
> the moment of action is one of the highest-leverage things in the product.

## Public attendance is opt-in and tiered

Attendance visibility for a community event is a gradient, and a friends-scoped action
never escalates a user's *identity* exposure. The tiers: (1) a private "I'm in" to friends;
(2) being counted in the event's **anonymous** headcount; (3) an explicit **public RSVP**
that puts your name/face on the event. Tapping "I'm in" on a friend's brought-along event
may move you to tier 2 (you're genuinely attending) but **never** to tier 3.

> **Why.** This is the [private-first](#private-first-public-never-touches-the-friends-surface)
> firewall applied to attendance: the most a friends-scoped action may leak across the
> public boundary is an anonymous +1, never *you*.

## Preserve the social graph; archive the content

In the v1→v2 cutover, **carry** profiles, the double-opt-in friend graph, and topic
interests into v2. **Do not port** event content (events/RSVPs/event-messages) — v1 keeps
it in a read-only archive. When porting cost trades against graph continuity, choose graph
continuity.

> **Why.** The friend graph is the literal foundation of v2's My Friends timeline — a v2
> with no friends is dead on arrival. It already exists in v1 in the exact shape v2 needs,
> so preserving it is near-free value. Event content, by contrast, is the public-aggregator
> baggage that doesn't map to ideas/activities and would impose constraints for little
> value.

## Phone number is the identity bridge

v2 runs on a fresh backend with fresh accounts. Match a v2 user to their v1 records by
**phone number**, never by user id (the ids differ across backends). The bulk pre-migration
and claim-on-login both key on phone.

## The client binds to the versioned API, never the schema

The mobile client talks **only** to a versioned API; it never queries the database schema
directly. Within a major version (`/v1`), the API evolves **additively** (tolerant reader:
never remove, retype, or repurpose a field a released client reads) and breaks by
**superseding** — a new path/field alongside the old, deprecate, then delete once the
upgrade floor (`min_supported_build`) passes the last build that used it. A new URL major
(`/v2`) is reserved for rare wholesale redesigns.

> **Why.** v1's fatal coupling was clients speaking the database schema directly: with
> unbounded mobile update timelines, the schema froze the day it had users. The versioned
> API is the indirection that lets the schema churn freely behind a stable contract. See
> `api/conventions.md` for the full model and the `/v1/ideas` worked example.

## Realtime is an enhancement, not a dependency

Every screen must render correctly from a plain authenticated fetch. Live updates (SSE)
layer on top to make the experience feel like a group chat — they are never load-bearing
for correctness. A client with no live channel (reconnecting, backgrounded, flaky network)
shows last-fetched state and catches up on next fetch.

> **Why.** v1 leaned on a realtime sync that was janky and coupling. v2 treats realtime as
> a progressive enhancement so correctness never depends on the live channel being up.
