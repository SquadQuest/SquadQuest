---
status: in-progress
depends: []
specs:
  - specs/architecture.md
issues: []
pr:
---

# Plan: v2 backend infrastructure (deploy the API online via tf/)

## Scope

Stand up the production hosting for the v2 backend in GCP project `squadquest-d8665`,
managed in `tf/` (OpenTofu). Today `tf/` manages **frontend hosting only** (DNS, two GCS
website buckets, a shared HTTPS LB, GitHub-Actions deploy SAs + Workload Identity). The
**backend is deployed nowhere** — Cloud Run, Cloud SQL, Secret Manager, and Artifact
Registry aren't even enabled. This plan mirrors the **proven jarvus-hq stack** (Cloud Run +
Cloud SQL on a private VPC, secrets in Secret Manager, image in Artifact Registry, CI deploy
via WIF) to put `api.squadquest.app` online.

**In:**

- **Remote tf state** — migrate `tf/` from local state (currently gitignored `terraform.tfstate`)
  to a GCS backend bucket. Load-bearing first step: shared infra must not live on one laptop.
- **Enable APIs:** `run`, `sqladmin`, `secretmanager`, `artifactregistry`, `vpcaccess`,
  `servicenetworking`, `compute` (already on). Manage via `google_project_service`.
- **Networking:** VPC + private-IP range + service-networking peering + a VPC Access connector
  (Cloud Run → Cloud SQL over private IP; no public DB IP).
- **Cloud SQL:** `POSTGRES_17` instance (match local `postgres:17-alpine`), private IP only,
  backups + PITR, `deletion_protection=true`; a `squadquest_v2` database + user with a
  `random_password`.
- **Secret Manager:** `database-url` (composed from the SQL private IP + generated password) and
  `jwt-secret` (generated; ≥32 chars per the env plugin). Cloud Run's compute SA gets
  `secretAccessor`.
- **Artifact Registry:** a Docker repo for the server image.
- **Server containerization:** a `server/Dockerfile` (Bun runtime) + `.dockerignore`; the server
  already reads `DATABASE_URL`/`JWT_SECRET`/`PORT`/`HOST` from env (`@fastify/env`).
- **Cloud Run service:** the API container, VPC-connected, env from secrets, `/v1/health`
  startup+liveness probes, `min_instances=1` (warm — friendly to the planned SSE/`LISTEN
  NOTIFY` realtime), public `run.invoker`.
- **Domain + TLS:** `api.squadquest.app` via Cloud Run domain mapping (managed cert) + a DNS
  record in the existing zone. (LB-fronting is an alternative; domain mapping matches jarvus-hq
  and is simpler.)
- **CI deploy:** extend `.github/workflows/v2-publish.yml` (or a sibling) to build + push the
  image and deploy Cloud Run, authenticating via the existing `v2-github-action` SA (granted the
  needed roles) — and run drizzle migrations against Cloud SQL on deploy.
- **Reconcile tf drift (import):** bring the currently-unmanaged, live infra into `tf/` so state
  reflects reality — the **v1 CI SA** `github-action-812828867@` and its project IAM bindings,
  the **Firebase** footprint (`firebase-adminsdk-755ie@` SA + enabled APIs: fcm, firebase,
  identitytoolkit, securetoken, firebasehosting, cloudfunctions, dynamiclinks), and the enabled
  APIs themselves. Import, don't recreate — v1 still ships from these.

**Out:** the storage bucket for user photos + signed URLs (that's the `storage` feature stage,
though this plan makes adding it trivial); SSE/realtime implementation (infra here just doesn't
preclude it); production SMS/OTP provider (Twilio-class — currently `ConsoleOtpProvider`);
rehosting v1 Supabase-stored `profile.photo` assets (a migration concern for the storage stage);
decommissioning v1's Firebase/Supabase.

## Implements

`specs/architecture.md` — the "managed Postgres", "owned backend", and deployment posture it
commits to. No new spec surface (infra/ops); if a durable hosting decision emerges (e.g.
"api.squadquest.app is the canonical v2 API origin"), capture it in `architecture.md` via its
own PR.

## Approach

Mirror jarvus-hq's `tf/` file layout (it's the reference implementation): split the current
monolithic `tf/main.tf` into `main.tf` (providers + **gcs backend** + `google_project_service`
- `variables`), `vpc.tf`, `cloudsql.tf`, `secrets.tf`, `artifact-registry.tf`, `cloudrun.tf`,
`iam.tf` (deploy-SA roles + WIF), keeping the existing frontend resources (DNS/buckets/LB) in
a `frontend.tf`. Reuse the existing `github` Workload Identity pool and `v2-github-action` SA
rather than creating jarvus-hq's `jarvus-hq-github-actions` equivalent — grant that SA the
deploy roles (`run.admin`, `artifactregistry.writer`, `cloudsql.client`, `secretmanager.viewer`,
`act-as` the compute SA). Note the existing WIF provider condition pins `ref=='refs/heads/develop'`
— fine for deploy-on-merge.

Phased, low-risk first (this session does Phase 0–1; later phases gated on review):

- **Phase 0 — state + drift (no new runtime infra):** create the tf-state GCS bucket, add the
  `backend "gcs"` block, `tofu init -migrate-state`. Refactor files. `tofu import` the v1 SA +
  Firebase + enabled-API resources so `tofu plan` is clean (no destroys). This is reversible and
  touches nothing live.
- **Phase 1 — data plane:** VPC + peering + connector, Cloud SQL instance + db + user, secrets.
  `tofu apply`. Verify connectivity.
- **Phase 2 — image:** `server/Dockerfile`, Artifact Registry repo, first image build/push.
- **Phase 3 — service:** Cloud Run service + IAM + domain mapping + DNS; migrations-on-deploy;
  CI wiring. Cut `api.squadquest.app` over.

## Validation

- [ ] `tofu init` against the GCS backend; state migrated off local; `tofu plan` clean (no
      unexpected creates/destroys — v1 drift imported, not recreated).
- [ ] APIs enabled via tf; `tofu plan`/`apply` idempotent on re-run.
- [ ] Cloud SQL reachable from Cloud Run over private IP; `DATABASE_URL`/`JWT_SECRET` resolve
      from Secret Manager at runtime.
- [ ] `server/Dockerfile` builds; image runs locally against a DB and serves `/v1/health`.
- [ ] Cloud Run service healthy (startup+liveness on `/v1/health`); `api.squadquest.app` serves
      `/v1/health` over TLS; migrations applied to Cloud SQL.
- [ ] CI deploy: merge to `develop` builds+pushes the image and rolls out Cloud Run green.
- [ ] v1 stays up throughout (its Firebase/CI infra untouched by the import).

## Risks / unknowns

- **Importing live v1 drift** is the delicate part — a wrong address or a `plan` that wants to
  *recreate* (not adopt) Firebase/SA resources could disrupt the still-shipping v1 app. Import
  one resource at a time; never `apply` until `plan` shows zero changes for imported resources.
- **Cloud SQL `deletion_protection` + tf**: keep it on; document the two-step (flip flag, then
  destroy) so nobody `tofu destroy`s the prod DB by reflex.
- **SSE on Cloud Run**: long-lived streams + request timeouts + scale-to-zero. `min_instances=1`
  - a generous request timeout mitigates; the realtime stage validates for real. A single
  instance also keeps one Postgres `LISTEN` connection simple.
- **State-bucket bootstrap chicken-and-egg**: the state bucket can't be in the state it backs;
  create it out-of-band (gsutil/console) or `create_before` with a local apply, then migrate.
- **Region**: existing frontend LB/buckets are multi-region `US` / `us-central1` provider
  default; jarvus-hq uses `us-east4`. Pick `us-central1` (provider default already set) for the
  backend to keep latency to the DB low and avoid a cross-region surprise.
- **Cost**: `min_instances=1` Cloud Run + a `db-f1-micro` Cloud SQL + connector run ~$ small-but-
  nonzero monthly even idle. Acceptable for launch; note it.

## Notes

(closeout)

## Follow-ups

(closeout)
