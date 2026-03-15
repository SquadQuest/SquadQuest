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

### The Timeline ("My Community")

The main screen is a **chat-like timeline**:

- Input at the bottom, scroll up for history (reverse ListView)
- Title bar says "My Community" — this is the global view of all your double-opt-in friends
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

### Squad Selector

The title bar is **tappable** to reveal a dropdown selector:

- "My Community" (default) — global view, all friends
- Named squads — persistent multi-member groups

**Squads** are the evolution of the group text thread:

- Captain-controlled membership (captain adds people)
- Within squads, you **CAN post arbitrary text messages** to the main timeline (unlike the global community view)
- Text messages in squads are threadable (same drawer UI, just without voting/activity features)
- Squad-level ideas/activities are visible to all squad members
- Any message can have **photo attachments** (text+photos, or photos-only, rendered as one unit like Slack)

### Audience Visibility

A persistent, contextual **audience indicator** sits above every input area. It updates based on what you're about to do:

- **Community context**: "Your friends see your ideas · threads are private"
- **Squad context**: "Visible to Paddle Kru members"
- **Idea composer open**: "This idea will be shared with all your friends" / "...with Paddle Kru"
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

### Not Yet Implemented

- Real backend integration (all mock data)
- Onboarding / login flow
- Profile management
- Friend connection flow
- Push notifications for ideas/activities
- Activity taxonomy management
- Captain controls (confirming time/location to promote idea → activity)
- Deep linking
- Actual photo upload/display
