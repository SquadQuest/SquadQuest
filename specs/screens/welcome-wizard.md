# Screen: Welcome Wizard

A first-launch intro shown over the app, establishing what SquadQuest is and why it's safe,
before/around the phone-OTP sign-in and v1 claim.

## Route

Full-screen `PageView` overlay on first launch (dismissable / skippable). After dismissal it
does not reappear. Sits in front of the bottom-nav shell.

## Data Requirements

None for the intro pages (static copy). The sign-in step uses
[`api/auth.md`](../api/auth.md); first verify performs the
[v1 claim](../behaviors/v1-migration.md).

## Display Rules

Three swipeable pages with distinct jobs (authentic, low-key voice — bookended by the
writer's copy, mechanic in the middle):

1. **"Rally the squad. Go hang."** — what SquadQuest is + free/privacy framing ("isn't a
   business… coordinate in-person activities with friends… mutually-confirmed friends can
   see your details and activity").
2. **"How it works"** — the mechanic in one line (share an idea, suggest times/places,
   friends vote, lock it in and go).
3. **"How is this free?"** — open-source/no-ads trust closer ("…built by and for its
   users").

- Skip button; final page has a "Let's go!"-style dismiss.

## Actions

- Swipe / skip through pages.
- Proceed to **phone sign-in** → OTP → on verify, **claim** the pre-migrated v1 profile +
  friend graph (the user lands in a populated My Friends timeline, not an empty one). A
  lightweight profile confirm may follow.

## Navigation

- Dismiss → My Friends timeline (claimed graph already present).

## Principles

**Inherited:**

- [Audience clarity at the moment of action](../principles.md#audience-clarity-at-the-moment-of-action)
  & [private-first](../principles.md#private-first-public-never-touches-the-friends-surface)
  — the trust framing in the copy is the product's privacy stance stated up front.
- [Preserve the social graph; archive the content](../principles.md#preserve-the-social-graph-archive-the-content)
  — claim-on-login is what makes the post-wizard timeline non-empty.

## Notes

- Copy is settled (3 screens). The friend-connection model is moving beyond
  phone-number-only (QR + other options), so screen 1/3 framing says "mutually-confirmed
  friends," not "only people with your phone number." Friend-connection flow is a future
  plan.
