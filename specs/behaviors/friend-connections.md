# Behavior: Friend Connections

## Rule

The friend graph is **double opt-in**: a connection exists only when both people have
agreed (`friendship.status = accepted`). You build it by **sending a request** (by phone
now; QR and other channels are future), and the other person **accepting**. Either side may
decline; absence of acceptance is not a connection.

## Applies To

`screens/friends-timeline.md` (whose audience is the accepted graph), `api/friends.md`,
`behaviors/v1-migration.md` (the pre-migrated graph arrives already-accepted; claim-on-login
surfaces pending requests).

## Details

- **Send by phone:** you request a friend by E.164 phone. Resolve the phone to a profile;
  if none exists, create an **unclaimed shell** (phone only) and attach the request to it —
  so when that person joins and claims (claim-on-login), the pending request is waiting.
  This is the same shell mechanism as the v1 migration.
- **One edge per pair:** a `friendship` row is unique per unordered pair. If an edge already
  exists (requested or accepted, either direction), sending is idempotent — never a duplicate.
  If *they* already requested *you*, your "send" is treated as an accept.
- **States:** `requested → accepted` (both connected) or `requested → declined` (no
  connection; may be re-requested later). A decline is not a block.
- **Respond:** only the **requestee** may accept/decline a `requested` edge.
- **Self:** you cannot friend yourself.
- **Visibility of details:** only `accepted` friends see each other's activity/timeline
  (the friends-timeline audience). A merely-`requested` edge grants nothing.

## The firewall / privacy note

Sending a request by phone reveals only that *you* reached out; it does not expose the
target's activity to you, nor yours to them, until accepted. Pending requests carry just
identity (name/photo when available), never timeline content.

## Principles

**Inherited:**

- [Private-first](../principles.md#private-first-public-never-touches-the-friends-surface) —
  the accepted graph is the entire private surface's gate; nothing is shared on a one-sided edge.
- [Preserve the social graph; archive the content](../principles.md#preserve-the-social-graph-archive-the-content)
  — shells + claim-on-login mean a request survives until the invitee joins.

## Local

- **Double opt-in, decline ≠ block.** v2 keeps v1's mutual-confirmation model (no one-way
  follows among friends; that's what communities are for). Declining simply leaves no edge;
  it isn't a permanent block (a future plan may add blocking). Promote if blocking arrives.
