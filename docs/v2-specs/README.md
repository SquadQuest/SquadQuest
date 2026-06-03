# SquadQuest V2 Redesign Specs

## The Problem V2 Solves

SquadQuest was supposed to help people snowball ad-hoc, activity-centric hangouts into reality. The real-world problem: you meet people at events and social gatherings who share your interests — you exchange numbers or Instagram handles, get excited about playing tennis or going hiking together — and then nothing ever happens. Or you invite them once, they're busy, and you conclude they must not really be interested.

A "why not" decision during v1 development to include "public" as an event visibility option (alongside "private" and "friends-only") led SquadQuest to become primarily a public event aggregator. The dominance of public events in what users see sets their assumption that posting an event means hosting a public event they're responsible for. This killed the core vision.

## V2 Philosophy

**Cut public events entirely.** Start with getting private/friends-only right. Public can potentially be layered back in later, but the foundation must be the intimate friend-to-friend coordination loop.

The experience should feel like a **group text**, not a social media feed. Input at the bottom, scroll up for history. No infinite timeline scrolling — this is a place where your friends casually coordinate doing things together.

**Lower the stakes of participation.** Everything in v2 is designed to be more passive and lower-pressure than traditional event invitations:

- Posting an "idea" is lighter than "hosting an event"
- Responding "Interested" is lighter than committing to an RSVP
- Getting notified that "Katie wants to have a picnic" is lighter than "You've been invited to Katie's Picnic"
- Ignoring/dismissing is passive (no explicit "decline" button needed)

## Core Concepts

### Two-Entity Lifecycle: Ideas → Activities

The central mechanic is a two-state entity:

1. **Idea** — Someone proposes an activity. "Katie wants to go rock climbing." The idea has:
   - 1 activity type from the taxonomy (required)
   - Optional proposed times (multiple options allowed)
   - Optional proposed locations (multiple options allowed)
   - A toggle for whether others can suggest alternative times/locations
   - An audience (all friends, or specific people)

2. **Activity** — When the captain (proposer) confirms a time and location, the idea becomes a confirmed activity. These may be the same database record in two states, not two separate objects.

The person who proposes is the **captain**. They control progression from idea → activity by selecting the final time/location. If they offered multiple options or enabled suggestions, participants can vote, and the captain decides based on the votes.

### Response System

When you see an idea or activity, you can respond:

- **"I'm in!"** — Committed / definitely going
- **"Interested"** — Want to, but not committing yet
- **"Next Time"** — Not this time, but keep me in the loop

There is no explicit "dismiss" or "decline" button — not responding is the passive dismiss. This avoids the social friction of visibly declining.

Responses are shown **inline on the timeline**. Unresponded items show all three buttons in a row beneath the card. After responding, the buttons collapse to a small chip showing your response (tappable to change).

### The Timeline ("My Friends")

The main screen is a **chat-like timeline**:

- Input at the bottom, scroll up for history (reverse ListView)
- Title bar says "My Friends" — this is the global view of all your double-opt-in friends (everyone you're connected with)
- Items on this timeline are **only ideas and activities** — no arbitrary text messages (that's what threads and squads are for)
- Each item shows its **audience context**: "Katie shared with all friends" or "Katie shared with you and 3 others" — this is compact, outside the card, as an author line (like a message sender)

Ideas and activities render as **compact attachment-style cards** beneath the author line (not full-width tiles). This maintains the group-text feel rather than a traditional social media feed. Ideas have dashed/dotted borders to visually convey their tentative nature. Activities have solid borders.

### Thread Drawer

Tapping any idea, activity, or squad text message opens a **right-side drawer** that covers ~85% of the screen width, leaving a left sliver of the main timeline visible (like Slack threads).

The thread drawer contains:

- **Rich header**: activity type, status (idea vs confirmed), members, audience
- **Response buttons** in the header (for ideas/activities)
- **Vote bar** (for ideas with proposed times/locations): a persistent section between header and chat. Collapsed state shows leading options as summary chips. Tap anywhere on the bar to expand and see full voting detail with all options, voter avatars, and "Suggest" buttons.
- **Chat messages**: arbitrary text, photos
- **Thread input**: text field with photo attachment button

Threads are where the real conversation happens — the main timeline stays clean with just ideas/activities.

### Context Selector

The title bar is **tappable** to reveal a dropdown with three kinds of context:

- **My Friends** (default) — global view, all your double-opt-in friends
- **Squads** — closed, persistent multi-member groups
- **Communities** — open, followable groups whose leaders broadcast events
- **Discover communities** — a stub entry point for finding new communities (communities are *found*, not added)

**Squads** are the evolution of the group text thread:

- Captain-controlled membership (captain adds people)
- **Closed** — only members see the timeline
- Within squads, you **CAN post arbitrary text messages** to the main timeline (unlike the global friends view)
- Text messages in squads are threadable (same drawer UI, just without voting/activity features)
- Squad-level ideas/activities are visible to all squad members
- Any message can have **photo attachments** (text+photos, or photos-only, rendered as one unit like Slack)

### Communities (the home for public events)

Communities are the controlled way public events come back into v2 — the thing v1 got wrong, done right. Where v1 blended public events into the same feed as everything else (training users to assume "if I post, it's public and I'm hosting"), v2 quarantines them behind an explicit context switch.

**Communities** are open, followable groups (the parallel construct to squads):

- **Open** — anyone can follow; follower counts can be large
- **Leaders broadcast only** — only community leaders post events. Followers RSVP and can comment in threads, but cannot post to the main community timeline. This is the crisp contrast with squads (where everyone posts) and matches how real groups work (a venue, a ride series, a yoga collective publish *to* their followers).
- The input area in a community context is replaced by a read-only **follower banner** ("Following · only leaders post events here") — there's no composer.

**Community events** are a distinct timeline item (`_CommunityEventItem`), not a friend idea/activity:

- **Born confirmed** — they skip the idea/voting stage entirely (a venue doesn't put its Monday jazz jam up for a vote)
- **Recurring** — they carry a recurrence ("Every other Wed", "Weekly · Mondays", "Tue / Thu / Sat / Sun")
- **Owned by the community**, audience = followers

**Dual attendance + the RSVP visibility gradient.** This is the centerpiece for dissolving the "I don't want strangers seeing me" fear. An event surfaces two numbers with two meanings:

1. **Private "I'm in"** — responding to a friend's brought-along idea (see below) is a promise *to your friends*, visible only to them
2. **Counted (anonymous)** — tapping "Going" on the event counts you toward the **distinct headcount** ("64 going") without revealing who you are
3. **Public RSVP** — a separate, explicit "Show name" toggle promotes your attendance to the public **face-pile** ("Maya, Jordan +6 publicly")

Tapping "Going" moves you to tier 2 automatically (you're genuinely attending); it never pushes you to tier 3. The gap between the headcount and the face-pile is intentional and reassuring. Going publicly implies going; un-going clears public.

**Seed examples** (modeled on real Philly groups): Wednesday Night Rides (bi-weekly social bike ride), Black Squirrel Club (Fishtown music venue), Philly River Flow (donation riverside yoga).

### Bringing Friends to a Community Event (the bridge)

The bridge is what makes communities *feed* the friends-first core instead of being a separate bulletin board. A "**Bring friends**" action on any community event:

- Switches context to **My Friends** and opens the idea composer **pre-filled** from the event (activity type, with the event attached as a read-only reference chip)
- Posts a **friends-scoped idea** that *embeds* the community event — the public event stays owned by the community; what lands on the friends timeline is a private, friends-scoped envelope
- The idea's **thread is the private logistics room** ("ride over from Clark Park at 6?") — the most private space in the app wrapped around the most public object, with a clean membrane between them

**The firewall invariant** (never violate): *the My-Friends composer only ever emits friends-scoped ideas; public exposure of self or event requires explicit community-context or public-RSVP action.* What crosses the fence from a friends-scoped action is at most an anonymous +1 to a headcount — never your identity.

**Growth loop**: friends discover communities by seeing each other bring events into the friends timeline → tap the embedded event → follow the community.

### Idea → Activity Transition (captain "lock it in")

The transition from a tentative idea to a confirmed activity is the heart of the original snowball pitch, and is now demonstrated in the mockup:

- A **"Lock it in"** captain CTA appears in the idea's vote bar (expanded). It picks the leading/voted time + location and promotes the idea to a confirmed activity — modeled as **two states of the same record** (the idea is resolved on the fly to an activity, reusing all activity rendering).
- A **brought-along idea** (linked to a community event) follows the *same arc*, but its time/place are pre-locked by the event, so the only open variable is "are we doing it." Its confirm bar reads "Time & place set by the event" and locking it in promotes it to an activity **linked to the community event**. It is never a dangling perpetual idea.

### Audience Visibility

A persistent, contextual **audience indicator** sits above every input area. It updates based on what you're about to do:

- **My Friends context**: "Your friends see your ideas · threads are private"
- **Squad context**: "Visible to Paddle Kru members"
- **Idea composer open**: "This idea will be shared with all your friends" / "...with Paddle Kru"
- **Bringing friends to an event**: "Sharing with all friends · about a Wednesday Night Rides event"
- **Community context**: read-only follower banner ("Following · only leaders post events here")
- **Thread drawer**: "Only participants in this thread can see replies"

This addresses the #1 fear that held people back in v1: uncertainty about who would see their posts.

### Unified Input Area

All posting happens from **one place at the bottom of the screen**:

- **Lightbulb button** (always visible): toggles the inline idea composer panel
- **Photo button** (squad context only): attach photos to messages
- **Text field**: active in squad context, guides to lightbulb in community context
- **Send button** (squad context only): send text/photo messages

The **idea composer** slides up from the input bar with:

- Horizontal scrolling activity type chips
- "Add times" and "Add locations" option buttons
- "Share" button (enabled once an activity type is selected)

No separate "create" button in the app bar — everything flows from one input area.

## Architecture

### Repo Structure

V2 lives alongside v1 in the same repository as a separate entrypoint:

```
lib/
├── main.dart              # v1 production app
├── storybook/main.dart    # storybook design explorer
├── v2/
│   ├── main.dart          # v2 app entrypoint
│   ├── app.dart           # V2App widget (theme, router)
│   ├── screens/           # v2 screens (copied from storybook, iterated freely)
│   └── components/        # v2 shared components
├── models/                # shared data models
├── controllers/           # shared Riverpod providers
├── services/              # shared services (supabase, auth, etc.)
└── theme.dart             # shared theme
```

Run with: `flutter run -t lib/v2/main.dart`

### Why This Structure

- **Same repo**: v1 and v2 share an evolving Supabase backend. Forking would cause merge hell.
- **Same bundle IDs**: v2 ships as an update to v1 in app stores. No migration needed for users.
- **Entrypoint selection**: No Flutter flavors needed — just `-t lib/v2/main.dart`.
- **Shared dependencies**: Single pubspec.yaml. V2 is simpler than v1, not adding exotic deps.
- **Independent screens**: v2 screens are copied from storybook and iterated freely — no dual-compatibility constraints.
- **Incremental migration**: Mock providers during demo phase, swap for real providers as backend evolves.

### Development Workflow

1. New screen designs start in **storybook** (`lib/storybook/screens/`)
2. When ready for the demo/app, **copy** into `lib/v2/screens/`
3. Iterate freely in v2 without worrying about storybook compatibility
4. Wire into v2's GoRouter in `lib/v2/app.dart`

## Current State (as of hackathon)

### Implemented in v2 app

- Community timeline with chat-like layout
- Idea cards (dashed borders, lightbulb icon, voting badge)
- Activity cards (solid borders, confirmed badge, time/location)
- Message-style card layout (avatar + author line outside, compact tile)
- Inline response buttons with collapse/expand animation
- Squad selector dropdown with context switching
- Thread drawer with header, chat, photos
- Persistent vote bar (collapsed summary chips → expandable full voting detail)
- Inline idea composer with activity type picker
- Contextual audience indicators above all input areas
- Photo attachments on messages (rendered as placeholders)
- **Idea → activity transition**: captain "lock it in" CTA promotes an idea to a confirmed activity (standard voting ideas + brought-along ideas)
- **Communities**: three seeded communities, follower-only read context, born-confirmed recurring event cards
- **Dual attendance + RSVP visibility gradient**: anonymous headcount + opt-in public face-pile (Going / Show name toggles)
- **Bring-friends bridge**: community event → pre-filled idea composer with embedded event reference; brought-along idea seeded on the friends timeline

### Not Yet Implemented

- Real backend integration (all mock data)
- Onboarding / login flow
- Profile management
- Friend connection flow
- Push notifications for ideas/activities
- Activity taxonomy management
- Deep linking
- Actual photo upload/display
- Community discovery / search (the "Discover communities" entry is a stub)
- Leader-side tooling (creating/managing a community and its events)
- Community event threads are read-only-ish (RSVP + bring-friends in header; chat reuses generic mock messages)
