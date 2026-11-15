# Gotchas — the bugs every implementation re-derives if not warned

These are real failures hit while building this pattern across projects. Each one
costs an hour of debugging if you don't know it up front.

## `ss` doesn't exist on macOS — and fails silently

The single worst one. A naive port check uses `ss -tlnp` (Linux). On macOS `ss`
isn't installed, the command fails, `2>/dev/null` swallows the error, the grep
matches nothing → **every port reads "free"** → every concurrent worktree picks
the *same* port and they collide. It looks like the port logic is broken; really
the detector is no-op'ing.

Fix (already in the `_common.sh` template): branch on the tool.

```bash
port_in_use() {
  if command -v lsof &>/dev/null; then
    lsof -iTCP:"$1" -sTCP:LISTEN -P -n &>/dev/null   # macOS + most Linux
  elif command -v ss &>/dev/null; then
    ss -tlnp 2>/dev/null | grep -q ":$1 "            # Linux without lsof
  else
    return 0                                          # unknown → assume in use
  fi
}
```

Also: **always scan from the default port**, not from `default+1` for worktrees.
If a worktree starts scanning at 4001, it skips a free 4000. Reuse the canonical
port whenever it's actually free; let real listen-state — not worktree identity —
decide collisions.

## Two collision axes: worktrees *and* other projects

The port logic above solves **intra-project** collisions — two worktrees of the
*same* repo never grab the same port. It does nothing about **inter-project**
collisions: run several Jarvus repos at once and they'd fight over ports if they
shared a base. In practice they don't, because each repo claims a distinct **base
port band** — e.g. one project in `25xx`, another in `35xx`, another's Postgres at
`5532`. That base is a per-project constant *you* choose; the worktree logic only
ranges within it.

Two ways to choose it:

- **Hand-pick** a distinct, uncommon high band per repo and keep PG + backend +
  frontend coherent within it (e.g. PG `N530`, backend `N531–N599`, frontend
  `N600–N699`). The traps: forgetting which bands are already taken, and splitting a
  repo across unrelated bands (one real repo runs Postgres on `5532` but its server
  on `4001–4099` — avoid that incoherence).
- **Derive it from a hash of the repo name** — collision-resistant with no registry
  to remember, the same trick the DB names use for worktree *paths*, applied at repo
  granularity:

  ```bash
  # deterministic base in a high block (20000–59990), distinct per repo name
  app_base_port() {
    local n; n=$(basename "$(app_root)" | cksum | cut -d' ' -f1)
    echo $(( 20000 + (n % 4000) * 10 ))
  }
  # then PG = base, backend range = base+1..base+49, frontend = base+50..base+99
  ```

## postgres:18 changed the data directory layout

On `postgres:18` the volume must mount at `/var/lib/postgresql`, **not**
`/var/lib/postgresql/data` (the path used through 17). Mount the wrong one and the
container's healthcheck never goes ready and `wait_for_postgres` times out after
30s.

**Pin the same major production runs.** Whatever major your prod DB is (Cloud SQL,
RDS, …), pin that in `_common.sh` so `app_strip_snapshot`'d snapshots restore without
version-mismatch surprises. That rule cuts both ways: when prod runs 18, you don't
get to stay on the 17 template default to dodge the mount change. The `_common.sh`
template carries the mount as `APP_PG_DATA_DIR` — for 18, change **both** lines
together:

```bash
APP_PG_IMAGE="postgres:18-alpine"
APP_PG_DATA_DIR="/var/lib/postgresql"     # NOT /var/lib/postgresql/data
```

Across Jarvus repos the major currently drifts (16 / 17 / 18 all in use) — match
*your* prod. And remember container-reuse (below): switching majors on an existing
container/volume needs a deliberate `docker rm` + volume removal.

## docker-compose can't do per-context isolation — evict Postgres from it

Compose pins one fixed DB name and one fixed host port — exactly what defeats
per-worktree databases and ports. It also breaks in this workflow specifically:
compose ties operations to the directory it was first run from, so when an agent
worktree is deleted while its compose containers keep running, you can't manage
them without recreating that exact path. So once these scripts exist, **remove the
Postgres service (and the app itself) from compose** — the `bin/` scripts manage a
path-independent shared container by name instead. Keeping a compose Postgres
alongside the bin/ one invites "which Postgres am I talking to?" confusion.

That's an eviction, not necessarily a deletion. Compose keeps exactly one job:
the **once-per-machine auxiliary-services runner** (a validator container, a local
OIDC IdP — see SKILL.md "Auxiliary services"). Those are shared across all
worktrees, never replicated per worktree, so compose's one-fixed-port model is
correct for them. If the file only templated Postgres, delete it outright.

## `cd` inside a piped/exec'd script

When a script needs to run a command in a subdir AND `exec`/background it with a
specific env, `cd "$dir"` before the `exec` is cleaner than wrapping in
`bash -c 'cd … && …'`. The single-service `dev` template does the former. The
fullstack `dev` backgrounds two children, so it uses subshells `( cd … && … ) &`.

## Container reuse vs. recreate

`ensure_postgres` reuses a container that already exists (just `docker start`s it
if stopped) and only creates one when absent. This is what lets many worktrees
share one Postgres. Don't `docker run` unconditionally — you'll get a name clash
or orphaned data. If you ever change Postgres image/version, you must `docker rm`
the old container (and possibly the volume) once, deliberately.

## A container's published address is frozen at creation — changing the bind silently does nothing

`ensure_postgres` reuses a container by name and only ever `docker start`s it
(that reuse is the whole point — it is what lets many worktrees share one
Postgres). Docker cannot re-publish an existing container, so **the `-p` address
is fixed at creation time**. Change `APP_PG_BIND` — or adopt the loopback
default after the fact — and every container created earlier keeps its old
publish, forever, with no error and no diff to notice.

This is how a machine ends up serving Postgres on `0.0.0.0` months after the
code moved to `127.0.0.1`. Seen in the wild: a container created in March still
published on all interfaces in August, on a box with a public IP, while its
repo's `_common.sh` had said `${APP_PG_BIND:-127.0.0.1}` the entire time. Every
code review of that file would pass.

The template now detects the drift and says what to do (normalising docker's
empty `HostIp`, which means all-interfaces):

```bash
# one address per line — a container can publish on SEVERAL, and concatenating
# them yields nonsense like "127.0.0.1100.116.60.123"; empty HostIp = all ifaces
actual="$(docker inspect \
  -f '{{range $p, $b := .HostConfig.PortBindings}}{{range $b}}{{if .HostIp}}{{.HostIp}}{{else}}0.0.0.0{{end}}{{"\n"}}{{end}}{{end}}' \
  "$container" | grep -v '^$' | sort -u | tr '\n' ' ' | sed 's/ *$//')"
[ -n "$actual" ] || actual="0.0.0.0"
[ "$actual" = "$bind" ] || echo "WARNING: ${container} publishes on ${actual}, not ${bind}" >&2
```

It warns rather than auto-recreating: recreating a container is the caller's
call, not a side effect of `bin/setup`. The fix is one deliberate command, and
the data is on a named volume so it survives:

```bash
docker rm -f <container> && bin/setup
```

The same freeze applies to any other creation-time setting — image/major
version, volume mount, env. Container reuse (below) is the general case; the
bind is the one where the silent failure is a *security* regression rather than
a broken container you would notice immediately.

## md5 binary differs across platforms

Linux/coreutils has `md5sum`; BSD/macOS has `md5 -q`. The `app_hash` helper
branches on which exists so worktree DB names are stable on both. Don't hard-code
`md5sum`.

## `trap 'kill 0' EXIT` can kill the caller

`kill 0` signals the **whole process group** — which is not "my children". A
script launched from a non-interactive shell (another script, a CI step, an
agent's exec call) *shares* its caller's process group, so a supervisor that
traps `kill 0` on EXIT takes the caller down with it the moment anything asks it
to stop. This is exactly the failure the old fullstack `dev` template had:
`bin/cleanup` would kill the dev session and then die mid-cleanup, killed by the
session's own trap.

Fix (in the current `dev-fullstack` template): `set -m` before backgrounding
children so **each child leads its own process group**, record the child pids,
and have the trap `kill -- -$child_pid` each group individually. That kills each
service's whole subtree (`bun run` → vite) without ever signalling the script's
inherited group.

## PIDs get recycled — record and verify start-time identity before killing

A pid file (or a `state.env`) can outlive its process: SIGKILL skips traps,
reboots reset the pid space, and the OS reuses pids. A later `kill -0 $pid`
proving "something is alive at that pid" is not proof it's *your* process — and
blindly `kill`ing it can shoot an innocent bystander. Record each pid **with its
start time** and re-verify before every liveness verdict and every kill:

```bash
app_pid_lstart() {          # start time of a live process; empty when gone
  { ps -o lstart= -p "$1" 2>/dev/null || true; } | sed 's/^ *//;s/ *$//'
}
# store: echo "SERVER_PID_LSTART=$(app_pid_lstart "$server_pid")"
# check: [ "$(app_pid_lstart "$pid")" = "$recorded_lstart" ]
```

The `_common.sh` template carries this as `app_pid_is`; the fullstack `dev` and
`gc` templates consult it before every kill and every health verdict.

## A single SIGTERM is not a teardown — escalate, then verify

`kill $pid` is a *request*. A process that traps SIGTERM and takes its time, or
ignores it outright, keeps running — and a stop path that fires one TERM,
deletes its state file, and returns 0 reports success while leaving a live
process holding a port and a database open. Observed in the wild: a `bin/dev
stop` exited 0, cleared `state.env`, and left a backend child alive for days;
it needed SIGKILL.

Deleting the state file is the part that turns a bug into an incident. That file
is the only record of the survivor's pid **and start time**, so once it's gone
the orphan can't be identified — you can't safely kill a bare pid (see pid
recycling above), so the process becomes unkillable-in-practice until reboot.

Every stop path therefore: TERM → wait → **KILL** → wait → **verify dead**, and
on survival keeps `state.env` and returns non-zero:

```bash
if ! app_kill_wait "$pid" "$lstart" TERM 25; then
  app_kill_wait "$pid" "$lstart" KILL 25 || survivors="${survivors} ${key}(${pid})"
fi
[ -n "$survivors" ] && return 1     # and do NOT rm state.env
```

Callers must honor the non-zero: `bin/cleanup` aborts rather than dropping a
database out from under a surviving process (the `DROP` would fail with
"database is being accessed by other users" anyway).

## Derive the child list from `state.env`, don't hardcode it in three places

The fullstack session records one `<NAME>_PID` per child. Early templates then
spelled that list out **three times** — the writer in `bin/dev`, the liveness
loop in `app_dev_session_healthy`, and the sweep loop in `app_dev_stop`. A stack
that grows a third process (an orchestrator, a worker) has to update all three,
and the failure is asymmetric: forget the *health* list and you get a false
"healthy"; forget the *sweep* list and every stop silently orphans that process,
while the other two lists still look correct in review.

Derive it from the state file instead — one list, no drift:

```bash
app_dev_child_keys() {   # every KEY_PID= in the snapshot, minus the supervisor
  printf '%s\n' "$1" | sed -n 's/^\([A-Z0-9_]*\)_PID=.*/\1/p' | grep -vx 'DEV' || true
}
```

Ports stay explicit: *which* ports must be listening is a real per-project
assertion, and `state.env` also carries ports that aren't liveness signals (an
aux container's published port).

## Commands that read stdin inside `while read` loops silently eat the stream

`docker exec -i` (what `app_psql` wraps), `gh`, `ssh`, `ffmpeg` — anything that
reads stdin — will, inside a `while read` loop fed on stdin, slurp the rest of
the loop's input as *its* stdin. No error: the loop just ends after the first
iteration that ran such a command. In a sweep like `bin/gc` that means "removed
one worktree, silently skipped the rest".

Fix: feed the loop on a **different file descriptor** so the commands inside
keep their normal stdin:

```bash
while IFS=$'\t' read -r -u 3 wt br locked prunable; do
  ...app_psql / gh calls...
done 3<<<"$records"
```

(`read -u 3` + `3<<<` — the gc template does exactly this.)

## macOS `TMPDIR` has a trailing slash — `"$TMPDIR"/*` patterns break

On macOS, `TMPDIR` is set to something like `/var/folders/.../T/` — **with a
trailing slash**. Appending `/*` yields `.../T//*`, and in a `case` glob (or any
pattern match) the double slash must match literally, so real tmp paths (from
`mktemp -d`, no double slash) silently fail the match. Anything gated on "is
this path under tmp?" — e.g. a guard that only `rm -rf`s recorded paths inside
tmp — then never fires on macOS.

Fix: strip the trailing slash before appending (two steps — bash can't nest
`${${TMPDIR:-/tmp}%/}`):

```bash
tmp="${TMPDIR:-/tmp}"; tmp="${tmp%/}"
case "$path" in
  /tmp/*|"$tmp"/*) rm -rf "$path" ;;
esac
```
