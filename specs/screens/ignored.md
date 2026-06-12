# Screen: Ignored

A recovery surface for everything the user has **ignored** — the safety valve that makes ignoring
safe to tap (see [dismissal is silent and reversible](../principles.md#dismissal-is-silent-and-reversible)).
Ignoring removes an incoming item from its normal surface; this is where it goes so it's never an
irreversible black hole. Authenticated.

## Route

`/ignored`. Reached from the **Profile** screen (a low-prominence link — it's a rarely-needed
recovery tool, not a primary surface).

## Data Requirements

- The caller's ignored incoming items, aggregated across types. As of the wants work this is:
  - **Friend requests** the caller ignored (`friendship` rows where the caller is requestee and
    `ignored_at` is set) — see [`api/friends.md`](../api/friends.md).
  - **Want invites** the caller hid (`want_invite` rows the caller ignored) — see
    [`api/wants.md`](../api/wants.md).
- Other ignorable item types join this list as they're built (one consistent surface).

## Display Rules

- A list of ignored items, grouped or labeled by type ("Friend request from …", "Want invite from
  …"), each showing who it's from + enough context to recognize it, and when it was ignored.
- Empty state: "Nothing ignored" — the common case; this screen is usually empty.
- The sender is **never** shown anything about this screen; it's purely the recipient's private view.

## Actions

- **Un-ignore** an item → it returns to its normal incoming surface (a friend request reappears in
  the requestee's incoming requests; a want invite reappears in the **Invited** list) exactly as if
  never ignored. The sender's view is unaffected throughout (it never changed when ignored, and
  doesn't change when un-ignored).
- Acting on an item directly from here where it makes sense (e.g. **Accept** an ignored friend
  request) is allowed — un-ignore is the minimum.

## Navigation

- **In:** Profile → "Ignored".
- **Out:** back → Profile; un-ignoring routes the item back to its home surface.

## Principles

**Inherited:**

- [Dismissal is silent and reversible](../principles.md#dismissal-is-silent-and-reversible) —
  this screen *is* the reversibility half of that principle. Ignoring is "hide from me," not
  "destroy"; this is where hidden things are recoverable, and nothing here is ever visible to the
  sender.
