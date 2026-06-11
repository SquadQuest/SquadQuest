---
status: done
depends: []
specs:
  - specs/architecture.md
issues: []
pr: 435
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

- [x] `tofu init` against the GCS backend; state migrated off local; `tofu plan` clean (v1
      drift imported, not recreated — "No changes" after import). [Phase 0, PR #433]
- [x] APIs enabled via tf; `tofu plan`/`apply` idempotent on re-run. [Phase 0]
- [x] Cloud SQL reachable from Cloud Run over private IP (`10.114.0.3`); `DATABASE_URL`/
      `JWT_SECRET` resolve from Secret Manager at runtime. [Phase 1]
- [x] `server/Dockerfile` builds (linux/amd64) + pushed to Artifact Registry. [Phase 2]
- [x] Cloud Run service healthy (startup+liveness on `/v1/health`); migrations applied to
      Cloud SQL on startup ("migrate: up to date"); `/v1/health` 200 + a real DB write
      (`POST /v1/auth/otp/request` → 200) over TLS at the run.app URL. [Phase 3]
- [x] `api.squadquest.app` over TLS → **200** (managed cert provisioned). Required
      `gcloud domains verify squadquest.app` so the domain appears in
      `gcloud domains list-user-verified` (Cloud Run's authz source — distinct from
      Search Console). Mapping + `api` CNAME (→ ghs.googlehosted.com) in tf.
- [x] CI deploy: `v2-publish.yml` `v2-backend` job builds+pushes the image (SHA-tagged) and
      `gcloud run deploy`s on push to develop; v2-github-action SA granted the deploy roles;
      tf `ignore_changes` on the image so CI + tf don't fight. (Verified on first merge.)
- [x] v1 stays up throughout (its Firebase/CI infra untouched by the import).

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

Shipped across **PRs #433 (Phase 0), #434 (Phase 1–3 + domain), #435 (CI auto-deploy)**.
The v2 backend is live at **<https://api.squadquest.app>** (managed TLS), Cloud Run
`squadquest-backend` (us-central1, min_instances=1) → private-IP Cloud SQL `squadquest-v2`
(POSTGRES_17), secrets in Secret Manager, image in Artifact Registry. Mirrors the jarvus-hq
stack. tf uses **remote state** (`gs://squadquest-tfstate`, versioned).

Key things learned / decided:

- **Migrate-on-startup**, not drizzle-kit: the image runs `src/migrate.ts` (drizzle-orm's
  programmatic migrator — a *prod* dep) inside the VPC against the private DB. drizzle-kit is a
  devDep and `--production` drops it.
- **Build linux/amd64** — Cloud Run is amd64; dev Macs are arm64. (CI runners are amd64, so the
  workflow uses a plain `docker build`.)
- **Domain authz**: Cloud Run checks `gcloud domains list-user-verified`, a *different* surface
  from Search Console. A Search-Console Domain property alone didn't satisfy it; `gcloud domains
  verify squadquest.app` did. A *stale failed* mapping object also caches its conditions — had to
  DELETE it so a fresh create re-checked authz.
- **CI vs tf ownership**: CI deploys the image (`gcloud run deploy --image`); tf owns the rest of
  the service. `lifecycle.ignore_changes` on the image + client annotations keeps them from
  fighting.
- **v1 drift adopted by import** (firebase APIs + the v1 CI SA), never recreated; v1 untouched.

## Follow-ups

- **Deferred to plan / `v2-sms-otp`:** production SMS OTP via Twilio Verify. The three secret
  *containers* (`twilio-account-sid`, `twilio-auth-token`, `twilio-verify-sid`) exist and are
  **populated** (set by hand); still need a `TwilioVerifyOtpProvider` + verify-route change
  (Twilio owns code gen/check) wired into Cloud Run env. Server still ships `ConsoleOtpProvider`.
- **Deferred (ops, when needed):** `bin/snapshot`/`load-snapshot` for prod data (no need yet);
  raising Cloud Run request timeout + validating SSE behavior when the realtime stage lands;
  rehosting v1 Supabase-stored `profile.photo` assets (belongs to the storage stage).
- **Tracked as:** `deletion_protection=true` on Cloud SQL — destroying the prod DB is a
  deliberate two-step (flip the flag in tf, apply, then destroy). Documented in cloudsql.tf.
- **None** outstanding for the infra itself — backend is live and CI-deployed.
