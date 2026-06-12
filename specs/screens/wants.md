# Screen: Wants ("Want to do")

The user's loose, shared pre-activities — things they want to do and the friends they'd do them
with, before there's a date (the `want` + `want_invite` entities — see
[`data-model.md`](../data-model.md), [`api/wants.md`](../api/wants.md)). Authenticated.

## Route

`/wants`. Reached from the **Profile** screen (see [`screens/profile.md`](profile.md)).

## Data Requirements

- **Yours:** `GET /v1/wants` — wants the caller owns (with their `invitees` + each invitee's
  response).
- **Invited:** `GET /v1/wants/invited` — wants friends invited the caller to (with `your_response`).

## Display Rules

- Two groupings: **Yours** (wants you created) and **Invited** (wants friends added you to).
- Each want shows its topic label and, when set, title + location. A small marker distinguishes
  `ongoing` from `one_shot`.
- **Yours:** show the invitee face-pile with their responses (who's `in` / `interested`). Never show
  a "declined" — there is none; non-responders simply don't show a positive chip.
- **Invited:** show who invited you + the three response controls (or your current response chip,
  collapsed — same pattern as activity cards, see
  [`behaviors/response-system.md`](../behaviors/response-system.md)).
- Empty state invites adding the first want ("Got a 'we should do that sometime' with a friend?
  Capture it here and make it happen").
- Archived wants hidden by default (a promoted one-shot drops off).

## Actions

- **Add** a want: pick a **topic** (required), optional title/location/notes, choose **kind**
  (one_shot default), and optionally **invite accepted friends**. → `POST /v1/wants`.
- **Invite / remove** friends on your want → `POST` / `DELETE /v1/wants/:id/invites…`. Only accepted
  friends are invitable. Inviting is what shares the want.
- **Respond** to a want you're invited to — **I'm in / Interested / Next time** (no decline; ignore
  to passively dismiss; or **hide** it from your invited list). → `PUT` / `DELETE
  /v1/wants/:id/response`, `DELETE /v1/wants/:id/invited`.
- **Edit / delete** your own want → `PATCH` / `DELETE /v1/wants/:id`.
- **Promote** (headline action, owner only): one tap opens the existing **idea composer pre-filled**
  — topic locked in; **audience pre-filled to the want's invitees** (editable); title/location seed
  the option hints. Publish to any channel you can already post to. The activity is created with
  `from_want` set; a `one_shot` archives, an `ongoing` stays. Promote reuses the composer — **no**
  parallel compose flow.

## Navigation

- **In:** Profile → "Want to do".
- **Out:** Promote → the idea composer (pre-filled) → on publish, the relevant timeline.

## Principles

**Inherited:**

- [Private-first](../principles.md#private-first-public-never-touches-the-friends-surface) —
  a want reaches a friend only via an explicit invite; an un-invited want is yours alone. Nothing
  public.
- [Lower the stakes of participation](../principles.md#lower-the-stakes-of-participation) —
  responding to a want invite is the same three soft options with a silent dismiss; no one is shown
  a "no".

## Notes

- A want is **upstream** of an idea (a latent intent), distinct from a *draft* (an idea you started
  composing). This screen is the shared backlog, not a drafts folder.
