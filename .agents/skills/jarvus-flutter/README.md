# jarvus-flutter

The Jarvus convention set for building cross-platform apps with **Flutter + Riverpod + go_router** —
screens, state management, declarative routing, the `dio` HTTP client, storybook component
development, and optional offline-first storage with drift. Deliberately no code generation (except
drift).

## When you'd want it

Any Flutter/Dart project — creating apps, adding screens, managing state with Riverpod, implementing
routing, or building offline-first features. Install it on a repo so an agent working on the app
follows the house patterns (Riverpod over Provider, hand-written `fromJson`/`toJson`, etc.).

## Install

**Recommended scope: per-project.** This encodes the stack *this* project uses, so installing it in
the repo means every developer (and their agents) gets the same guidance — version-controlled with
the code and updated alongside it.

```bash
npx skills add JarvusInnovations/agent-skills --skill jarvus-flutter
```

(Add `--global` if you'd rather have it available everywhere.) See `SKILL.md` for the stack and patterns
and `references/` for offline-first and other deep dives.
