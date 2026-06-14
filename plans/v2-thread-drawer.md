---
status: done
depends: []
specs:
  - specs/behaviors/thread-drawer.md
issues: []
pr: 475
---

# Plan: v2 thread drawer — the right-side Slack-thread surface

> `specs/behaviors/thread-drawer.md` describes the central interaction: tapping any idea,
> activity, community event, or squad message opens a **right-side drawer** with a rich
> target-adaptive header, a persistent vote bar (ideas), and the conversation. Today these
> tap to a **full-screen** `ActivityDetailScreen` (ideas/activities) or `ThreadScreen` (messages,
> community events), with options/vote/confirm/suggest already working but laid out top-to-bottom
> on a plain screen. This brings the surface into spec conformance: one drawer, all four targets.

## Scope

**In:**

- A **`ThreadDrawer`** that slides in from the right (~92% width, scrim + X to close, full
  height) via `showGeneralDialog` + a right-edge slide transition.
- **Target-adaptive header:**
  - *Idea/activity* — type + state (idea/confirmed) + response controls + audience.
  - *Community event* — reuse `CommunityEventCard` (community/recurrence/time/place + RSVP
    gradient + bring-friends), with a new `inThread` flag to disable its own self-tap.
  - *Squad message* — sender + body preview, no voting.
- **Vote bar (ideas with options only):** persistent section between header and chat.
  **Collapsed** = summary chips of the leading time/place; **tap to expand** = full detail
  (all options, vote toggles, captain Confirm, "Suggest" when `allow_suggestions`). Brought-along
  ideas (`event_ref`) instead show "Time & place set by the event" + the captain Confirm.
- **Conversation:** reuse the existing `ThreadView` message list + reply input, with the spec'd
  **audience hint** on the input ("Only participants in this thread can see replies").
- Repoint the three tap targets (`_ActivityTile`, `_MessageTile`, community event card) to open
  the drawer.

**Out (kept as-is / later):**

- The full-screen `ActivityDetailScreen` + `/activity/:id` and `/thread/:targetType/:targetId`
  routes stay wired as a **fallback** (deep-links still work) — user's call. The drawer becomes
  the primary tap target.
- **Voter avatars** in the vote bar — the `ActivityOption` model carries vote *counts* + your-vote
  only, not the voter list; show counts + your-vote highlight, note the gap (model/serializer
  change is its own follow-up).
- Realtime patch-in of new messages/votes while the drawer is open — already an enhancement; the
  drawer renders from the fetch and `threadProvider` invalidates on reply/vote as today.

## Implements

`specs/behaviors/thread-drawer.md` — the drawer chrome, the adaptive header, the persistent
collapse/expand vote bar, and the audience-stamped thread input. No spec change (the spec is
already correct; this is code→spec conformance).

## Approach

1. **Refactor `thread_view.dart`** minimally: keep `ThreadView` (used by the fallback detail
   screen), but ensure the reply input carries the audience hint. Extract nothing structural the
   drawer can't reuse directly.
2. **`CommunityEventCard`** — add `inThread = false`; when true, drop the self-`InkWell` so it
   renders as a static header inside the drawer.
3. **`thread_drawer.dart`** — `showThreadDrawer(context, {required target})` where target is a
   sealed/enum over {activity, communityEvent, squadMessage}. Builds the header + vote bar (for
   activities, lifting the options/vote/confirm/suggest logic out of `ActivityDetailScreen` into a
   shared `_VoteBar` widget so both surfaces share it) + `ThreadView`.
4. **Repoint taps** in `timeline_screen.dart` (`_ActivityTile`, `_MessageTile`) + the community
   card to call `showThreadDrawer` instead of `context.push`.
5. Tests: drawer opens for each target; vote bar expands; reply input shows the audience hint.

## Validation

- [x] Tapping an idea/activity tile opens the drawer with the rich header + vote bar.
- [x] Tapping a squad message opens the drawer (sender header, no vote bar).
- [x] Tapping a community event opens the drawer (event header + RSVP, no vote bar).
- [x] Vote bar starts collapsed (leading-option chips) and expands to options + vote/confirm +
      Suggest (when `allow_suggestions`); brought-along shows the event-set + confirm variant.
- [x] Thread reply input shows the private-audience hint.
- [x] `flutter analyze` clean; `flutter test` green (46 tests, +4).

## Risks / unknowns

- `showGeneralDialog` slide-from-right + scrim is the lightest path to the "floating over the
  app bar + input" feel without a router change; verify it covers the FAB + bottom composer.
- Sharing the vote/confirm/suggest logic between the drawer and the fallback detail screen
  without duplicating: extract a `_VoteBar`/controller used by both.
- Nested gesture arenas again (RSVP chips inside the event header inside the drawer) — same
  Material handling as the card fix; verify chips still win their taps.

## Notes

Drawer is `showGeneralDialog` + a right-edge `SlideTransition` (92% width, scrim, full height
over the app bar + composer) — lightest path to the "floating" feel without a router change.
The vote bar (`thread_vote_bar.dart`) is its own self-contained widget so the
options/vote/confirm/suggest + collapse/expand logic lives in one place.

**Deviation from the plan's step 1:** I did *not* retrofit the shared `ThreadVoteBar` into the
fallback `ActivityDetailScreen`. That screen still has its own (working, tested) always-expanded
options list, and since the drawer is now the primary tap target nobody reaches the detail screen
in normal flow. Forcing the shared widget in would have changed the fallback's UX and broken its
passing tests for zero user-facing gain — so the two intentionally differ for now. Shipped in #475.

## Follow-ups

- **Deferred** — voter avatars in the vote bar (the `ActivityOption` model/serializer carries
  vote *counts* + your-vote only, not the voter list; needs a backend serializer change). Shows
  counts + your-vote highlight for now.
- **Deferred** — realtime patch-in of new messages/votes while the drawer is open (renders from
  fetch + invalidates on action today; the stream-driven live update rides on the broader
  realtime story).
- **Tracked as** — the fallback `ActivityDetailScreen` could later be retired (or re-skinned to
  reuse `ThreadVoteBar`) once the drawer is confirmed to cover every entry point; left wired as a
  deep-link fallback per the scope decision.
