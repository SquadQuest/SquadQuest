# jarvus-dev-flow

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

**Recommended scope: per-project.** The workflow is set up once, but it is how work gets done in the
repo every day, and the practices behind it keep improving. Installed in the repo, the skill is how
those updates reach the project. Each one arrives as a diff, and the agent can apply it to the
repo's tooling.

```bash
npx skills add JarvusInnovations/agent-skills --skill jarvus-dev-flow
```

Then ask your agent to set up the bin/ workflow. See `SKILL.md` for the full scaffold and
`references/` for the deep dives.
