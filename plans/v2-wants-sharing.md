---
status: cancelled
depends: [v2-wants-core]
specs: []
issues: []
pr:
---

# Plan: v2 wants — sharing (CANCELLED — superseded by invites)

> **Cancelled at pickup.** This stub assumed wants would carry a `visibility {private|shared}` flag
> and that friends would *browse* each other's shared lists. During `v2-wants-core` design that
> model was replaced: a want is a **shared pre-activity** where the owner **invites specific
> friends** (the `want_invite` entity). Privacy is derived (no invitees = private); inviting is the
> entire sharing mechanism. There is no "browse a friend's wants" surface to build, so this plan has
> no remaining scope.
>
> Friend-invites + responses ship in **`v2-wants-core`**. The only deferred social feature is the
> mutual-wants *signal* across un-connected wants, tracked in **`v2-wants-overlap`**.
