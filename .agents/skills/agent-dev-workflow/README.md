# agent-dev-workflow

Scaffolds an **agent-friendly local dev workflow**: a `bin/` task-runner (modeled on GitHub's
*scripts-to-rule-them-all*) over a shared Postgres container that gives **every git worktree its own
isolated database and port**, plus a dedicated test database so tests can never wipe your dev data.

## When you'd want it

A Postgres-backed project where you want any of:

- multiple copies of the backend running concurrently on one machine (one per worktree),
- the `setup` / `run` / `cleanup` contract that AI agent orchestrators (Conductor and similar) expect,
- a fullstack `bin/dev` that runs as an **attach-aware per-worktree singleton** — a second invocation
  reuses the healthy running session (`KEY=VALUE` endpoints on stdout, `status`/`stop`/`logs`
  subcommands, on-disk `.dev/logs/`) instead of double-booting,
- a `bin/gc` that **sweeps merged agent worktrees** — proof-based (ancestry / `git cherry` / merged
  PR), stopping their dev sessions and dropping their derived databases along the way,
- a `bin/stop` that **shuts the shared Postgres container down** once it proves nothing is using it
  — no live dev session in any worktree, no client connections — for when idle project containers
  pile up on one machine,
- an end to tests clobbering local dev/demo data,
- a replacement for a docker-compose-just-for-local-Postgres setup.

If there's no database — or no concurrency need *and* tests already use a separate DB — the payoff
is small.

## Install

**Recommended scope: global.** You reach for this to *bootstrap* a project's dev workflow, often
before the repo has any skills wired up — so it's most useful installed once for all your projects.

```bash
npx skills add --global JarvusInnovations/agent-skills --skill agent-dev-workflow
```

Then ask your agent to set up the bin/ workflow. See `SKILL.md` for the full scaffold and
`references/` for the deep dives.
