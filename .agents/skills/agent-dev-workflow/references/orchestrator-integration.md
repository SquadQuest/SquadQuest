# Orchestrator integration (Conductor, etc.)

The reason this pattern exists: AI agent orchestrators spin up a **separate git
worktree per session** and let you register **setup / run / cleanup** commands.
Many sessions run on one machine at once, so each needs its own database and port
with zero manual config. These scripts provide exactly that contract.

## The contract

- **setup** → `bin/setup`. Idempotent: ensures the shared container, creates this
  worktree's DB (derived from its path), installs deps, migrates. It **prints
  `KEY=VALUE` env lines to stdout** and all human status to **stderr** — so an
  orchestrator can capture stdout and inject those vars into the run step. The
  stdout block must be **complete**: `DATABASE_URL` + `APP_DATABASE`, *every*
  derived port (one per process kind — `PORT`, `GRPC_PORT`, `VITE_PORT`, …), the
  inter-service wiring vars (`ORCHESTRATOR_URL=http://localhost:${GRPC_PORT}`),
  and the shared aux-service endpoints (`VALIDATOR_URL=…` — see SKILL.md
  "Auxiliary services"). Apps that read discrete `DB_*` vars instead of a URL:
  emit both forms (`app_db_env`).
- **run** → `bin/dev` (or `bin/server`). Picks the same free ports and derives the
  same DB, so it works whether or not the orchestrator threaded `setup`'s output
  through. The single-service variant `exec`s for clean signal handling; the
  fullstack variant is a supervised singleton with its own attach/status/stop
  contract (next section). Binds **loopback by default**
  (`HOST=127.0.0.1`): an orchestrator that needs LAN exposure must opt in
  explicitly — and must never widen a dev-auth-bypass instance (an
  AUTH_DISABLED-style everyone-is-admin mode) beyond loopback. If the
  orchestrator health-checks the service, `curl` works for HTTP ports but **not
  gRPC** — probe those with a plain TCP connect.
- **cleanup** → `bin/cleanup`. Drops this worktree's DB (refuses the canonical
  one without `--force`); stops the recorded dev session first (`app_dev_stop`
  handles both `.dev/state.env` sessions and legacy `.dev.pid` ones). Leaves
  the shared container up for other worktrees.

## The dev-session contract (fullstack `bin/dev`)

The fullstack `dev` template is a **per-worktree singleton** with an explicit
machine contract, so an orchestrator (or a second agent in the same worktree)
can discover, attach to, health-check, and stop a session without guessing:

- **Singleton + attach.** One session per worktree. A second `bin/dev` against
  a healthy session starts nothing — it prints the running session's endpoints
  and exits 0. A session still *booting* (another `bin/dev`'s pre-flight:
  postgres ensure, migrate) is waited on and then attached, never torn down. A
  stale or half-dead session (a child gone, recycled pids after a reboot) is
  torn down and replaced automatically. `bin/dev --restart` bounces whatever is
  there.
- **`KEY=VALUE` on stdout.** Start and attach both emit the session's env block
  (`STATUS=running`, `DEV_PID`, `DATABASE_URL`, `PORT`, `VITE_PORT`, `LOG_DIR`)
  on stdout — human status stays on stderr, same discipline as `bin/setup` — so
  one stdout capture tells the orchestrator where the stack landed either way.
- **`bin/dev status` exit codes.** `0` running (healthy: every recorded pid is
  the exact recorded process *and* every port listens) / `1` stopped (no
  session) / `2` unhealthy (recorded session not fully up — replace or stop it)
  / `3` starting (boot in progress — re-check shortly, or run `bin/dev` to wait
  and attach). Script against the codes; the stdout block accompanies 0 and 3.
- **On-disk logs.** Each service's full output lands in
  `.dev/logs/<service>.log` (e.g. `server.log`, `web.log`) — fresh per session,
  kept after exit for post-mortems, size-capped for long-lived sessions
  (`APP_DEV_LOG_CAP_BYTES`). Agents read the files; humans can `bin/dev logs
  [service]` from any terminal.
- **Attach refusal on mismatch.** Attaching exits 2 when the running session
  wasn't started with the caller's explicit `DATABASE_URL`/`PORT`/`VITE_PORT`
  overrides — never exit 0 with settings the caller didn't ask for.
- **`bin/dev stop`** stops the recorded session from any terminal; one child
  dying tears down the whole stack loudly (never a half-dead session serving
  errors from still-bound ports).

## Why stdout/stderr discipline matters

An orchestrator captures a script's stdout to learn where the service landed
(`PORT=4002`). If status chatter ("Creating database…", "Running migrations…")
goes to stdout too, it pollutes that capture. Rule: **machine-parseable env →
stdout; everything humans read → stderr.** Every template here follows it.

## Identity is the worktree path

DB name and port both derive from the worktree, so two sessions never collide and
re-running setup in the same worktree is a no-op-or-reset (not a duplicate).
`git worktree list --porcelain | head -1` identifies the main worktree (canonical
DB + default port); everything else is a hashed-path derivative. An orchestrator
needs no per-session config — just register the three scripts once.

## Override hooks

Every derived value has an env override for when an orchestrator wants explicit
control: `APP_DATABASE`, `APP_PG_PORT`, `PORT`, `VITE_PORT`, plus one per extra
process kind (`GRPC_PORT`, …) and `HOST` (default loopback). Honor these first in
every script (the templates do).
