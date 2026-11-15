# Production snapshots (optional — only if the project has a prod DB)

Some projects want to load production-like data locally. This is **purely
opt-in** and only makes sense once there's a production database to snapshot. A
greenfield project (no prod yet) should skip all of this — adding it early is
dead weight.

When a project *does* have real prod data, this is usually its **seeding
strategy**: `bin/load-snapshot` (default → latest) replaces hand-written fixtures
entirely (the "snapshot-as-seed" posture in **`migrations-and-seeds.md`**). One
caveat for clean restores: pin the **same Postgres major as production** locally, so
an `app_strip_snapshot`'d dump doesn't hit version-mismatch surprises.

Two scripts, both built on helpers already in `_common.sh`.

## bin/snapshot — export prod → object storage

For a GCP Cloud SQL prod instance, export server-side (no public IP / maintenance
mode needed) to a bucket:

```bash
gcloud sql export sql "$INSTANCE" "gs://${BUCKET}/${filename}" \
  --database="$DATABASE" --project="$PROJECT" --clean --if-exists --quiet
```

Cloud SQL refuses to overwrite an existing object, so `rm` it first. The Cloud
SQL service account needs write access to the bucket (`roles/storage.objectAdmin`
on the bucket, or reuse an existing tfstate/snapshots bucket). A bucket lifecycle
rule (e.g. delete after 30 days) keeps snapshots from accumulating.

## bin/load-snapshot — load a snapshot into this context's DB

Accept a local path **or** a `gs://` URL (stream straight from the bucket — no
local download). Drop → recreate → load → migrate:

```bash
snapshot="${1:-gs://${BUCKET}/latest.sql}"
app_recreate_db "$(app_db_name)"
if [[ "$snapshot" == gs://* ]]; then
  gcloud storage cat "$snapshot" | app_strip_snapshot | app_psql -d "$(app_db_name)"
else
  app_strip_snapshot < "$snapshot" | app_psql -d "$(app_db_name)"
fi
app_migrate "$(app_database_url)"   # applies any migrations newer than the snapshot
```

`bin/setup <snapshot>` does the same in one step (see the setup template).

## app_strip_snapshot — the provider filter hook

Managed Postgres dumps carry directives a vanilla local Postgres chokes on, so
`bin/setup` pipes every snapshot through `app_strip_snapshot`. `_common.sh`
ships it as an **identity filter** (`cat`) — a plain `pg_dump` needs no
filtering, and shipping it defined is what keeps `bin/setup <snapshot>` from
dying with a bare `command not found` on a verbatim copy of the template.

Override it per provider. Cloud SQL's wrapper injects `\restrict`/`\unrestrict`
psql meta-commands and `GRANT … TO cloudsqlsuperuser` (a role that doesn't exist
locally):

```bash
app_strip_snapshot() {
  grep -v -E '^\\(restrict|unrestrict) |cloudsqlsuperuser'
}
```

Non-GCP equivalents: AWS RDS → `aws rds ...` or `pg_dump` over the wire to S3;
self-hosted → plain `pg_dump`. The shape is identical (export → object store →
stream into `app_recreate_db` + load + migrate); only the export command and the
provider-specific `app_strip_snapshot` filter change.
