# Behavior: v1 → v2 Migration

## Rule

The v1 social graph is carried into v2 via a **one-time bulk pre-migration** that copies v1
**profiles + accepted friendships + topic subscriptions** into the fresh v2 backend as
**claimable shells keyed by phone number**, before launch. A user **claims** their shell on
first v2 login (phone-OTP). v1 **event content is never ported**. Everyone opens v2 to
their full friend graph on day one.

## Applies To

- First-login / onboarding flow (`screens/welcome-wizard.md` → claim step)
- `api/auth.md` (claim happens during phone-OTP verify)
- Every screen that reads the friend graph (`screens/friends-timeline.md`, friend pickers)

## Details

### Identity bridge: phone number

The v2 backend is fresh, so v2 `auth`/`profile` ids differ from v1's. **Phone number is the
only join key** between v1 and v2 records (see
[principles: phone is the identity bridge](principles.md#phone-number-is-the-identity-bridge)).
Every v1 profile has a phone (it's `not null` in v1). The pre-migration and the login-claim
both match on normalized phone.

### What carries vs. what is archived

- **Carry:** `profile` (name, photo, phone), **accepted** `friendship` edges, `topic`
  subscriptions.
- **Do not carry:** events (`instances`), RSVPs (`instance_members`), `event_messages`,
  `location_points`. These stay in v1, served read-only by the v1 web archive.
- Pending/declined v1 friend requests are **not** carried (only `accepted` edges); v2
  relationships re-consent through v2's flows where needed.

### Bulk pre-migration (before launch)

A one-time, **idempotent** job reads the v1 Postgres **read-only** and writes v2 records:

1. For each v1 profile → upsert a v2 `profile` **shell** keyed by phone, `claimed_at = null`.
2. For each **accepted** v1 friendship → create the v2 `friendship` edge between the two
   shells (status `accepted`).
3. For each topic subscription → recreate the topic + subscription on the shell.

- Idempotent on phone: re-running updates shells in place, never duplicates. Safe to run
  repeatedly up to launch to catch late v1 changes.
- Why bulk (not lazy per-login): friendships are **bilateral**. A shell must exist for
  *both* endpoints for the edge to exist, so the graph can only be whole if everyone is
  pre-staged. Lazy per-login import would leave the day-one timeline empty until both sides
  happened to migrate — rejected for that reason.

### Claim-on-login

On first successful phone-OTP verify (`api/auth.md`):

1. Find the `profile` shell by phone.
2. Bind it to the new v2 auth identity and set `claimed_at`.
3. Surface a lightweight profile confirm (name/photo) — the user may update; v2 connection
   flows (QR, etc.) layer on top of the carried graph, they don't replace it.

- If no shell exists for the phone (a brand-new user who wasn't in v1), create a fresh
  profile — claim is a no-op merge.

### Un-migrated friends

A carried friendship may point at a friend whose shell exists but who **hasn't logged into
v2 yet** (`claimed_at = null`). Such friends:

- **Are** part of the graph (the edge is real; they appear in friend lists/counts).
- Render as **"not on v2 yet · invite"** — their ideas/activities won't appear (they've
  posted none), and they can be nudged to claim.
- Become fully active the moment they claim, with no re-friending needed.

### Cutover

- v2 ships as an **app-store update** to v1 (same bundle id). On update, the client points
  at the v2 API and the user re-authenticates by phone (→ claim).
- The v1 **native** app is superseded; the v1 **web** build stays up read-only as the event
  archive.
- The handful of live future v1 events are not ported; hosts/attendees can be notified, and
  the archive remains viewable. (Low volume — handled operationally, not by porting.)

## Principles

**Inherited** — these especially govern this behavior:

- [Preserve the social graph; archive the content](../principles.md#preserve-the-social-graph-archive-the-content)
  — the entire what-carries / what-archives split is this principle applied.
- [Phone number is the identity bridge](../principles.md#phone-number-is-the-identity-bridge)
  — the join key for both the bulk job and the login claim.
