# SquadQuest Specs

This directory is the **source of truth** for SquadQuest v2. Specs declare the desired
state of the software; the implementation is brought into conformance with them. The spec
leads; the code follows.

> v2 is a ground-up re-envisioning focused on private/friends-only activity coordination,
> with public events reintroduced only inside opt-in Communities. It is being built as a
> custom Fastify/Bun + Postgres backend with a versioned API and a Flutter client
> (`lib/v2/`). See `architecture.md` for the stack and `principles.md` for the philosophy.

## How to use these specs

1. **Read the relevant spec before implementing.** Every screen, endpoint, and behavior
   has (or should have) a spec. It answers *what* must be true, not *how* to build it.
2. **If the spec is ambiguous, fix the spec** — don't guess in code.
3. **If the code must change behavior, change the spec first** (or in the same PR).
4. **Check your work against the spec** when done — every display rule, action, contract.

## Layout

```
specs/
├── README.md            # this file
├── principles.md        # the decisive, project-wide rules (the philosophy, written down)
├── architecture.md      # stack, entrypoints, backend topology, foundational decisions
├── data-model.md        # the v2 schema: carried / new / archived
├── api/                 # the client↔server contract
│   ├── conventions.md   # versioning, auth, error envelope, pagination, realtime transport
│   └── <endpoint>.md
├── screens/             # one file per v2 screen/route (what the user sees + can do)
└── behaviors/           # cross-cutting rules spanning multiple screens
```

## Principles flow

`principles.md` holds the project-wide principles. Individual specs carry a `## Principles`
section that **references down** the `principles.md` entries that especially bite there
(with a one-line gloss of how), plus any principle local to that one spec. A local
principle that starts governing a second spec gets **promoted** up to `principles.md`, and
the copies replaced with references. References point one direction only: specs → `principles.md`.

## Relationship to plans

Specs describe **state** (what should be true). `plans/` describes **motion** (how we get
there next). Work starts with a plan that names the specs it implements. See `plans/README.md`.

## Spec drift

`specs/` is only useful if it tracks reality. Run `/audit-spec-drift` to compare the specs
against the implementation and surface gaps, undocumented behavior, and conflicts. Treat
spec↔code divergence as a bug, not debt.
