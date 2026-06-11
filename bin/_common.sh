# Shared functions for SquadQuest v2 development scripts.
# Source this file, don't execute it directly.
#
# A single shared postgres container hosts a separate database per context
# (main worktree, each agent worktree, the test runner) so nothing clobbers
# anything. See plans/v2-dev-bin-scripts.md.

set -euo pipefail

SQ_PG_USER="squadquest"
SQ_PG_PASSWORD="squadquest"
SQ_PG_IMAGE="postgres:17-alpine"
SQ_CONTAINER_NAME="squadquest-v2-postgres"
SQ_VOLUME_NAME="squadquest-v2-pgdata"

sq_root() {
  git rev-parse --show-toplevel
}

sq_server_dir() {
  echo "$(sq_root)/server"
}

sq_pg_port() {
  echo "${SQ_PG_PORT:-5532}"
}

# Is a TCP port already being listened on? Uses lsof on macOS, ss on Linux —
# `ss` does NOT exist on macOS and fails *silently*, which would make every port
# look free and let concurrent worktrees collide on the same port. If neither
# tool is present we assume "in use" so we skip the port rather than double-bind.
port_in_use() {
  if command -v lsof &>/dev/null; then
    lsof -iTCP:"$1" -sTCP:LISTEN -P -n &>/dev/null
  elif command -v ss &>/dev/null; then
    ss -tlnp 2>/dev/null | grep -q ":$1 "
  else
    return 0
  fi
}

# First free port in [start, end]. Always scans from the default so the main
# worktree's port is reused when free (rather than skipped).
find_available_port() {
  local start="${1:-4001}" end="${2:-4099}" port
  for port in $(seq "$start" "$end"); do
    if ! port_in_use "$port"; then
      echo "$port"
      return
    fi
  done
  echo "ERROR: no available backend port in range ${start}-${end}" >&2
  return 1
}

# The backend port for this context:
#   PORT set        → that port (orchestrator/explicit wins)
#   port 4000 free  → 4000 (the canonical default; reused whenever available)
#   otherwise       → first free port in 4001-4099 (concurrent worktrees)
# Scanning always starts at 4000 so we never skip it just because we're in a
# worktree — collisions are detected by actual listen-state, not worktree identity.
sq_pick_port() {
  if [ -n "${PORT:-}" ]; then
    echo "$PORT"
    return
  fi
  if ! port_in_use 4000; then
    echo "4000"
    return
  fi
  find_available_port 4001 4099
}

# Portable 8-char hex hash of a string (md5sum on Linux/coreutils, md5 on BSD/macOS).
sq_hash() {
  if command -v md5sum &>/dev/null; then
    echo -n "$1" | md5sum | head -c 8
  else
    echo -n "$1" | md5 -q | head -c 8
  fi
}

# Portable 8-char hex hash of a string (md5sum on Linux/coreutils, md5 on BSD/macOS).
sq_hash() {
  if command -v md5sum &>/dev/null; then
    echo -n "$1" | md5sum | head -c 8
  else
    echo -n "$1" | md5 -q | head -c 8
  fi
}

is_main_worktree() {
  local worktree_root main_worktree
  worktree_root="$(sq_root)"
  main_worktree="$(git worktree list --porcelain | head -1 | sed 's/^worktree //')"
  [ "$worktree_root" = "$main_worktree" ]
}

# The database name for this context:
#   SQ_DATABASE set      → that name (the test runner sets it to squadquest_test)
#   main worktree        → squadquest_v2 (canonical; existing dev data lives here)
#   other worktree       → sq_<hash-of-path> (isolated per worktree)
sq_db_name() {
  if [ -n "${SQ_DATABASE:-}" ]; then
    echo "$SQ_DATABASE"
    return
  fi
  if is_main_worktree; then
    echo "squadquest_v2"
  else
    echo "sq_$(sq_hash "$(sq_root)")"
  fi
}

sq_database_url() {
  echo "postgres://${SQ_PG_USER}:${SQ_PG_PASSWORD}@localhost:$(sq_pg_port)/$(sq_db_name)"
}

ensure_postgres() {
  local container="$SQ_CONTAINER_NAME" port
  port="$(sq_pg_port)"

  if docker inspect "$container" &>/dev/null; then
    if [ "$(docker inspect -f '{{.State.Running}}' "$container")" != "true" ]; then
      echo "Starting existing postgres container..." >&2
      docker start "$container" >/dev/null
    fi
  else
    echo "Creating postgres container on port ${port}..." >&2
    docker run -d \
      --name "$container" \
      -p "127.0.0.1:${port}:5432" \
      -e POSTGRES_USER="$SQ_PG_USER" \
      -e POSTGRES_PASSWORD="$SQ_PG_PASSWORD" \
      -e POSTGRES_DB=squadquest_v2 \
      -v "${SQ_VOLUME_NAME}:/var/lib/postgresql/data" \
      "$SQ_PG_IMAGE" >/dev/null
  fi

  wait_for_postgres
}

wait_for_postgres() {
  local container="$SQ_CONTAINER_NAME" attempts=0
  while ! docker exec "$container" pg_isready -U "$SQ_PG_USER" -q 2>/dev/null; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 30 ]; then
      echo "ERROR: postgres did not become ready after 30 seconds" >&2
      return 1
    fi
    sleep 1
  done
}

# psql inside the container (no host psql needed). Default DB = maintenance 'postgres'.
sq_psql() {
  docker exec -i "$SQ_CONTAINER_NAME" psql -U "$SQ_PG_USER" "$@"
}

# Create the given database if it doesn't exist.
sq_ensure_db() {
  local db="$1" exists
  exists="$(sq_psql -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '${db}'" 2>/dev/null || true)"
  if [ "$exists" != "1" ]; then
    echo "Creating database ${db}..." >&2
    sq_psql -d postgres -c "CREATE DATABASE ${db} OWNER ${SQ_PG_USER}" >/dev/null
  fi
}

# Drop + recreate the given database (terminates active connections first).
sq_recreate_db() {
  local db="$1"
  sq_psql -d postgres -c "
    SELECT pg_terminate_backend(pid)
    FROM pg_stat_activity
    WHERE datname = '${db}' AND pid <> pg_backend_pid()
  " >/dev/null 2>&1 || true
  echo "Dropping database ${db}..." >&2
  sq_psql -d postgres -c "DROP DATABASE IF EXISTS ${db}" >/dev/null
  echo "Creating database ${db}..." >&2
  sq_psql -d postgres -c "CREATE DATABASE ${db} OWNER ${SQ_PG_USER}" >/dev/null
}

# Run drizzle-kit migrations against the given DATABASE_URL.
sq_migrate() {
  local url="$1"
  echo "Running migrations..." >&2
  (cd "$(sq_server_dir)" && DATABASE_URL="$url" bun run db:migrate) >&2
}
