# Screen: Wants ("Want to do")

The signed-in user's personal backlog of activities they want to do (the `want` entity — see
[`data-model.md`](../data-model.md), [`api/wants.md`](../api/wants.md)). Authenticated; this slice
shows **only your own** wants.

## Route

`/wants`. Reached from the **Profile** screen (see [`screens/profile.md`](profile.md)).

## Data Requirements

- The caller's own wants via `GET /v1/wants` (active by default). Each item: topic label, optional
  title/location/notes, `visibility`, `kind`, `archived_at`.

## Display Rules

- A list of the caller's **active** wants (newest first), each showing its topic label and, when
  set, title + location. A small marker distinguishes `ongoing` (a standing aspiration) from
  `one_shot`, and `shared` from `private`.
- Empty state invites adding the first want ("Keep a list of things you want to do — add one tap to
  turn it into a plan").
- Archived wants are hidden by default (a promoted one-shot drops off the active list); an
  optional toggle may reveal them (`?include_archived=true`).

## Actions

- **Add** a want: pick a **topic** (required, the noun-verb taxonomy), optional title/location/
  notes, choose **visibility** (private default) and **kind** (one_shot default). → `POST /v1/wants`.
- **Edit / delete** a want (own only) → `PATCH` / `DELETE /v1/wants/:id`.
- **Promote** (the headline action): one tap opens the existing **idea composer pre-filled** from
  the want (topic locked in; title/location seed the option hints), letting the user publish to any
  channel they can already post to (My Friends, a squad, the bring-friends bridge). On publish the
  activity is created with `from_want` set; a `one_shot` want archives, an `ongoing` want stays.
  Promote reuses the existing idea composer / [`POST /v1/ideas`](../api/wants.md#post-v1wantsidpromote)
  — it does **not** add a parallel compose flow.

## Navigation

- **In:** Profile → "Want to do".
- **Out:** Promote → the idea composer (pre-filled) → on publish, the relevant timeline.

## Principles

**Inherited:**

- [Private-first](../principles.md#private-first-public-never-touches-the-friends-surface) —
  a want's `shared` visibility is "a friend may browse my backlog," never public; private wants are
  owner-only. (Friend-browsing itself is a later stage; this screen shows only your own.)

## Notes

- A want is **upstream** of an idea (a latent intent), distinct from a *draft* (an idea you started
  composing). This screen is the backlog, not a drafts folder.
