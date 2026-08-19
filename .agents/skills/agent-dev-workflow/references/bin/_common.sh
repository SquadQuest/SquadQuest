# Shared functions for <PROJECT> development scripts. Source this; don't run it.
#
# This is the invariant core of the agent-dev-workflow pattern. A single shared
# Postgres container hosts a SEPARATE DATABASE per context (main checkout, each
# agent worktree, the test runner), and each context binds a free port — so many
# worktrees run at once without clobbering each other.
#
# TO ADAPT: replace the `app`/`APP_` prefix with a short one for your project
# (e.g. a 2-3 letter initialism) and set the constants below. Pick a PG host port
# well outside the common 5432 to avoid colliding with other local Postgres instances.

set -euo pipefail

APP_PG_USER="app"
APP_PG_PASSWORD="app"
# Pin the SAME Postgres major production runs (see gotchas.md). postgres:18
# moved the data directory — if prod is 18, change BOTH lines together:
#   APP_PG_IMAGE="postgres:18-alpine"
#   APP_PG_DATA_DIR="/var/lib/postgresql"        # NOT .../data on 18
APP_PG_IMAGE="postgres:17-alpine"
APP_PG_DATA_DIR="/var/lib/postgresql/data"
APP_CONTAINER_NAME="app-postgres"
APP_VOLUME_NAME="app-pgdata"

app_root() {
  git rev-parse --show-toplevel
}

# Where the backend lives. Single-package repo → app_root; monorepo → a subdir
# (e.g. "$(app_root)/server" or "$(app_root)/apps/server"). Adjust per project.
app_server_dir() {
  echo "$(app_root)"
}

app_pg_port() {
  # CHANGE THIS. 5532 is a placeholder, not a recommendation — pick a port in
  # this project's own band (see SKILL.md "base port band"). Never 5432: a
  # host Postgres, a stray docker-compose, or another project using the
  # default will collide, and the failure looks like "my data disappeared"
  # rather than a port conflict.
  echo "${APP_PG_PORT:-5532}"
}

# ── Database naming: one DB per context ──────────────────────────────────────
# APP_DATABASE set → that name (the test runner / orchestrator forces this).
# main worktree    → the canonical name (your durable dev data).
# other worktree   → app_<hash-of-path> (isolated, stable per worktree).
# The repo's main worktree — `git worktree list` always reports it first.
# Single source of truth: is_main_worktree, app_db_name_for_root and bin/gc's
# canonical-DB guard all resolve it through here. Takes an optional directory
# to resolve from (any path inside the repo); defaults to the current context.
app_main_worktree() {
  git -C "${1:-$(app_root)}" worktree list --porcelain | head -1 | sed 's/^worktree //'
}

is_main_worktree() {
  [ "$(app_root)" = "$(app_main_worktree)" ]
}

# Portable 8-char hex hash (md5sum on Linux/coreutils, md5 on BSD/macOS).
app_hash() {
  if command -v md5sum &>/dev/null; then
    echo -n "$1" | md5sum | head -c 8
  else
    echo -n "$1" | md5 -q | head -c 8
  fi
}

# Derived DB name for an ARBITRARY worktree root of this repo — bin/gc needs
# it for worktrees other than the current one. Main worktree → the canonical
# name; any other → app_<hash-of-path>. APP_DATABASE is deliberately NOT
# consulted here: that override belongs to the *current* context only
# (app_db_name below).
app_db_name_for_root() {
  local root="$1" main_worktree
  main_worktree="$(app_main_worktree "$root")"
  if [ "$root" = "$main_worktree" ]; then
    echo "app"
  else
    echo "app_$(app_hash "$root")"
  fi
}

app_db_name() {
  if [ -n "${APP_DATABASE:-}" ]; then
    echo "$APP_DATABASE"
    return
  fi
  app_db_name_for_root "$(app_root)"
}

app_database_url() {
  echo "postgres://${APP_PG_USER}:${APP_PG_PASSWORD}@localhost:$(app_pg_port)/$(app_db_name)"
}

# Not every app reads DATABASE_URL — some consume discrete DB_HOST/DB_PORT/…
# vars. Emit BOTH forms from bin/setup (uncomment there), or better: teach the
# app DATABASE_URL with a discrete-var fallback so one URL rules everywhere.
app_db_env() {
  echo "DB_HOST=localhost"
  echo "DB_PORT=$(app_pg_port)"
  echo "DB_NAME=$(app_db_name)"
  echo "DB_USER=${APP_PG_USER}"
  echo "DB_PASSWORD=${APP_PG_PASSWORD}"
}

# ── Snapshot load filter ─────────────────────────────────────────────────────
# Managed-Postgres dumps carry directives a vanilla local Postgres chokes on,
# so bin/setup pipes every snapshot through this hook. Identity by default:
# a plain pg_dump needs no filtering, and an UNDEFINED function here aborts
# `bin/setup <snapshot>` with a bare "command not found" (exit 127).
# Override per provider — Cloud SQL (see snapshots.md):
#   app_strip_snapshot() { grep -v -E '^\\(restrict|unrestrict) |cloudsqlsuperuser'; }
app_strip_snapshot() {
  cat
}

# ── Shared Postgres container ────────────────────────────────────────────────
ensure_postgres() {
  local container="$APP_CONTAINER_NAME" port
  port="$(app_pg_port)"
  if docker inspect "$container" &>/dev/null; then
    if [ "$(docker inspect -f '{{.State.Running}}' "$container")" != "true" ]; then
      echo "Starting existing postgres container..." >&2
      docker start "$container" >/dev/null
    fi
  else
    echo "Creating postgres container on port ${port}..." >&2
    docker run -d \
      --name "$container" \
      -p "${APP_PG_BIND:-127.0.0.1}:${port}:5432" \
      -e POSTGRES_USER="$APP_PG_USER" \
      -e POSTGRES_PASSWORD="$APP_PG_PASSWORD" \
      -e POSTGRES_DB=app \
      -v "${APP_VOLUME_NAME}:${APP_PG_DATA_DIR}" \
      "$APP_PG_IMAGE" >/dev/null
  fi
  wait_for_postgres
}

wait_for_postgres() {
  local container="$APP_CONTAINER_NAME" attempts=0
  while ! docker exec "$container" pg_isready -U "$APP_PG_USER" -q 2>/dev/null; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 30 ]; then
      echo "ERROR: postgres did not become ready after 30 seconds" >&2
      return 1
    fi
    sleep 1
  done
}

# psql inside the container — no host psql needed. Default DB = maintenance 'postgres'.
app_psql() {
  docker exec -i "$APP_CONTAINER_NAME" psql -U "$APP_PG_USER" "$@"
}

app_ensure_db() {
  local db="$1" exists
  exists="$(app_psql -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '${db}'" 2>/dev/null || true)"
  if [ "$exists" != "1" ]; then
    echo "Creating database ${db}..." >&2
    app_psql -d postgres -c "CREATE DATABASE ${db} OWNER ${APP_PG_USER}" >/dev/null
  fi
}

app_recreate_db() {
  local db="$1"
  app_psql -d postgres -c "
    SELECT pg_terminate_backend(pid) FROM pg_stat_activity
    WHERE datname = '${db}' AND pid <> pg_backend_pid()
  " >/dev/null 2>&1 || true
  echo "Dropping database ${db}..." >&2
  app_psql -d postgres -c "DROP DATABASE IF EXISTS ${db}" >/dev/null
  echo "Creating database ${db}..." >&2
  app_psql -d postgres -c "CREATE DATABASE ${db} OWNER ${APP_PG_USER}" >/dev/null
}

# Run migrations against a DATABASE_URL. PROJECT-SPECIFIC — see migrations-and-seeds.md.
app_migrate() {
  local url="$1"
  echo "Running migrations..." >&2
  (cd "$(app_server_dir)" && DATABASE_URL="$url" bun run db:migrate) >&2
}

# ── Per-context port picking ─────────────────────────────────────────────────
# CRITICAL (see gotchas.md): use lsof on macOS, ss on Linux. `ss` does NOT exist
# on macOS and fails *silently* — without this split every port reads "free" and
# concurrent worktrees all collide on the same port. If neither tool exists,
# assume "in use" so we skip rather than double-bind.
port_in_use() {
  if command -v lsof &>/dev/null; then
    lsof -iTCP:"$1" -sTCP:LISTEN -P -n &>/dev/null
  elif command -v ss &>/dev/null; then
    ss -tlnp 2>/dev/null | grep -q ":$1 "
  else
    return 0
  fi
}

# First free port in [start, end].
find_available_port() {
  local start="$1" end="$2" port
  for port in $(seq "$start" "$end"); do
    if ! port_in_use "$port"; then
      echo "$port"
      return
    fi
  done
  echo "ERROR: no available port in range ${start}-${end}" >&2
  return 1
}

# The backend port for this context. Always scans FROM the default so the main
# port is reused when free (not skipped on worktree identity); collisions are
# detected by real listen-state. Override with PORT.
app_pick_port() {
  if [ -n "${PORT:-}" ]; then echo "$PORT"; return; fi
  if ! port_in_use 4000; then echo "4000"; return; fi
  find_available_port 4001 4099
}

# The frontend (Vite) port — used by the fullstack dev variant; harmless to
# keep in single-service repos. Override with VITE_PORT.
app_pick_vite_port() {
  if [ -n "${VITE_PORT:-}" ]; then echo "$VITE_PORT"; return; fi
  if ! port_in_use 4100; then echo "4100"; return; fi
  find_available_port 4101 4199
}

# Multi-process backends: a worktree may run SEVERAL processes (HTTP API + gRPC
# service + Vite, …). Add one picker PER PROCESS KIND, each with a DISJOINT range
# inside the project's band (e.g. HTTP 4000-4049, gRPC 4050-4099, Vite 4100-4199 —
# shrink app_pick_port's range to match), and have bin/setup emit every derived
# port plus the wiring vars between them (e.g. ORCHESTRATOR_URL). Readiness note:
# gRPC ports aren't curl-checkable — probe with a plain TCP check, e.g.
# `(exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null`.
# app_pick_grpc_port() {
#   if [ -n "${GRPC_PORT:-}" ]; then echo "$GRPC_PORT"; return; fi
#   if ! port_in_use 4050; then echo "4050"; return; fi
#   find_available_port 4051 4099
# }

# ── Dev session state (fullstack bin/dev singleton) ─────────────────────────
# The fullstack bin/dev runs as a per-worktree SINGLETON. A running session
# records itself in .dev/state.env (supervisor PID, child PIDs, chosen ports,
# DATABASE_URL) and writes each service's output to .dev/logs/<service>.log.
# These helpers are shared by bin/dev (attach/status/stop), bin/cleanup, and
# bin/gc. Single-service repos (the plain `dev` template, which just execs)
# don't use them — harmless to keep either way.
#
# The helpers assume the fullstack template's two children (SERVER + WEB) and
# two ports (PORT + VITE_PORT). A stack with more processes only has to record
# them in bin/dev as <NAME>_PID / <NAME>_PID_LSTART: the health check and the
# stop sweep both DERIVE their child list from state.env (app_dev_child_keys),
# so neither needs editing. Only the PORT list in app_dev_session_healthy is
# still explicit, and deliberately so.

app_dev_state_dir() { echo "$(app_root)/.dev"; }
app_dev_state_file() { echo "$(app_dev_state_dir)/state.env"; }
app_dev_log_dir() { echo "$(app_dev_state_dir)/logs"; }

# ── PID identity ─────────────────────────────────────────────────────────────
# A bare `kill -0 $pid` proves only that SOME process has that pid. state.env
# survives a SIGKILLed supervisor and a reboot, and the OS recycles pids —
# so every recorded pid is stored WITH its start time, and both the health
# check and the stop path refuse to treat (or kill!) a recycled pid as ours.

# Start time of a live process; empty when the pid is gone.
app_pid_lstart() {
  { ps -o lstart= -p "$1" 2>/dev/null || true; } | sed 's/^ *//;s/ *$//'
}

# True when $1 is alive AND is the exact process recorded as ($1, $2).
# An empty recorded start time (state written by an older bin/dev) falls
# back to plain liveness so in-flight sessions stay stoppable across the
# upgrade.
app_pid_is() {
  local pid="$1" lstart="$2"
  [ -n "$pid" ] || return 1
  if [ -z "$lstart" ]; then
    kill -0 "$pid" 2>/dev/null
    return
  fi
  [ "$(app_pid_lstart "$pid")" = "$lstart" ]
}

# ── State reads ──────────────────────────────────────────────────────────────
# Deliberately not `source`d: sourcing would clobber caller-provided env
# overrides (PORT, VITE_PORT, ...) that the port pickers honor. The file can
# vanish between any two reads (a dying supervisor's trap removes it), so
# callers that need a COHERENT view take one app_dev_snapshot and read every
# key from it — never a healthy-check against one read and an emit from
# another.
app_dev_snapshot() {
  cat "$(app_dev_state_file)" 2>/dev/null || true
}

app_snap_get() {
  printf '%s\n' "$1" | sed -n "s/^$2=//p" | head -1
}

# One-off single-key read (no coherence needed). Empty when file is missing.
app_dev_state_get() {
  app_snap_get "$(app_dev_snapshot)" "$1"
}

# Healthy = the boot finished (PHASE=running), the supervisor and both
# services are alive AND are the exact recorded processes (pid + start time),
# and both ports are listening. Anything less is a half-dead stack that
# should be torn down, not attached to — a dead backend behind a live
# frontend port serves nothing but proxy errors, and a foreign listener on
# our recorded port is someone else's stack, not ours.
# Takes an optional snapshot; snapshots itself when not given one.
app_dev_session_healthy() {
  local snap="${1:-$(app_dev_snapshot)}"
  local key port
  [ -n "$snap" ] || return 1
  [ "$(app_snap_get "$snap" PHASE)" = "running" ] || return 1
  # Supervisor + every recorded child, derived from the state file (see
  # app_dev_child_keys) so a stack that grows a process is covered here
  # without a second list to keep in sync.
  for key in DEV $(app_dev_child_keys "$snap"); do
    app_pid_is "$(app_snap_get "$snap" "${key}_PID")" \
      "$(app_snap_get "$snap" "${key}_PID_LSTART")" || return 1
  done
  # Ports stay EXPLICIT: which ports must be listening for the stack to be
  # "up" is a real per-project assertion, and state.env also carries ports
  # that are not liveness signals (an aux container's published port).
  for key in PORT VITE_PORT; do
    port="$(app_snap_get "$snap" "$key")"
    [ -n "$port" ] || return 1
    port_in_use "$port" || return 1
  done
}

# Booting = state.env claimed (PHASE=booting) by a supervisor that is still
# alive. Distinct from unhealthy: a boot in progress should be WAITED ON,
# never torn down — the pre-state window (postgres ensure, migrate, seed) can
# run 10+ seconds and would otherwise be indistinguishable from a half-dead
# session.
app_dev_session_booting() {
  local snap="${1:-$(app_dev_snapshot)}"
  [ -n "$snap" ] || return 1
  [ "$(app_snap_get "$snap" PHASE)" = "booting" ] || return 1
  app_pid_is "$(app_snap_get "$snap" DEV_PID)" "$(app_snap_get "$snap" DEV_PID_LSTART)"
}

# Every recorded child key in a snapshot — derived from the state file itself
# (any KEY_PID=, minus the supervisor's own DEV_PID) rather than a hardcoded
# list. The list used to be spelled out here AND in app_dev_session_healthy
# AND in bin/dev's state writer; a stack that grew a third process had to
# update all three, and forgetting the one here orphaned that process on every
# stop while both other lists looked correct.
app_dev_child_keys() {
  printf '%s\n' "$1" | sed -n 's/^\([A-Z0-9_]*\)_PID=.*/\1/p' | grep -vx 'DEV' || true
}

# Signal one recorded (pid, lstart) pair by process GROUP and wait for it to
# die. bin/dev runs under `set -m`, so each child leads its own group and the
# group kill takes grandchildren (bun run → vite) down too; plain pid is the
# fallback for pre-`set -m` state. Returns 0 when the process is gone.
app_kill_wait() {
  local pid="$1" lstart="$2" sig="$3" deadline="$4" i
  app_pid_is "$pid" "$lstart" || return 0
  kill -"$sig" -- -"$pid" 2>/dev/null || kill -"$sig" "$pid" 2>/dev/null || true
  for i in $(seq 1 "$deadline"); do
    app_pid_is "$pid" "$lstart" || return 0
    sleep 0.2
  done
  ! app_pid_is "$pid" "$lstart"
}

# Stop the recorded session: TERM the supervisor (its signal-aware EXIT trap
# kills each child's process group), then sweep anything that outlived it
# (e.g. a SIGKILLed supervisor). Every kill is identity-checked — a recycled
# pid is never signalled — and every TERM ESCALATES to KILL for anything that
# ignores or is too slow to handle it. Also stops legacy .dev.pid-only
# sessions from the pre-singleton fullstack template.
#
# Returns non-zero when something survived even SIGKILL, and in that case
# DELIBERATELY LEAVES state.env in place: the file is the only record of the
# survivor's pid + start time, and deleting it turns a findable orphan into an
# untraceable process holding a port and a database open. A later bin/dev or
# bin/cleanup re-reads it and retries the kill. Silent when nothing is running.
app_dev_stop() {
  local snap state pid lstart child clstart key survivors
  state="$(app_dev_state_file)"
  # Snapshot everything up front: the supervisor's own EXIT trap removes
  # state.env, so it can vanish the moment the kill below lands.
  snap="$(app_dev_snapshot)"
  survivors=""
  if [ -n "$snap" ]; then
    pid="$(app_snap_get "$snap" DEV_PID)"
    lstart="$(app_snap_get "$snap" DEV_PID_LSTART)"
    if app_pid_is "$pid" "$lstart"; then
      echo "Stopping dev session (PID ${pid})..." >&2
      # 10s for the supervisor's trap to unwind its children gracefully.
      if ! app_kill_wait "$pid" "$lstart" TERM 50; then
        echo "bin/dev: supervisor ${pid} ignored SIGTERM — escalating to SIGKILL" >&2
        app_kill_wait "$pid" "$lstart" KILL 25 || survivors="${survivors} DEV(${pid})"
      fi
    fi
    # Sweep every recorded child that outlived the supervisor.
    for key in $(app_dev_child_keys "$snap"); do
      child="$(app_snap_get "$snap" "${key}_PID")"
      clstart="$(app_snap_get "$snap" "${key}_PID_LSTART")"
      app_pid_is "$child" "$clstart" || continue
      if ! app_kill_wait "$child" "$clstart" TERM 25; then
        echo "bin/dev: ${key} (PID ${child}) ignored SIGTERM — escalating to SIGKILL" >&2
        app_kill_wait "$child" "$clstart" KILL 25 || survivors="${survivors} ${key}(${child})"
      fi
    done
    if [ -n "$survivors" ]; then
      echo "bin/dev: ERROR: survived SIGKILL:${survivors}" >&2
      echo "bin/dev: keeping $(app_dev_state_file) so these stay identifiable" >&2
      return 1
    fi
    rm -f "$state"
  fi
  local legacy
  legacy="$(app_root)/.dev.pid"
  if [ -f "$legacy" ]; then
    pid="$(cat "$legacy" 2>/dev/null || true)"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      echo "Stopping legacy dev session (PID ${pid})..." >&2
      # The legacy supervisor traps only EXIT — a bare TERM kills it without
      # its `kill 0` trap ever running, orphaning its children. When it
      # leads its own process group (interactive launches), kill the whole
      # group; only then is -$pid guaranteed to be ITS group and nobody else's.
      if [ "$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')" = "$pid" ]; then
        kill -- -"$pid" 2>/dev/null || true
      else
        kill "$pid" 2>/dev/null || true
      fi
    fi
    rm -f "$legacy"
  fi
  return 0
}
