# =============================================================================
# Cloud Run — the v2 backend API service
# =============================================================================
# Containerized Fastify/Bun reaching shared-pg over the Cloud SQL socket
# mount, env from Secret Manager, min_instances=1 warm + request-based
# billing. Migrations run on container startup (see server/Dockerfile +
# src/migrate.ts).

variable "backend_image" {
  description = "Fully-qualified backend container image (AR). CI overrides per-deploy."
  type        = string
  default     = "us-central1-docker.pkg.dev/squadquest-d8665/squadquest-backend/api:bootstrap"
}

variable "api_domain" {
  description = "Public hostname for the API."
  type        = string
  default     = "api.squadquest.app"
}

resource "google_cloud_run_v2_service" "backend" {
  name     = "squadquest-backend"
  location = "us-central1"

  template {
    # Long-lived SSE (GET /v1/stream) is bounded by the request timeout. The 300s
    # default forced a reconnect every 5 min (verified in prod); raise to the 60-min
    # max so the heartbeat'd stream holds for an hour between reconnects. The client
    # reconnects + refetches regardless (realtime is best-effort) — this just makes
    # the cadence humane. See specs/behaviors/realtime.md + plans/v2-realtime-sse.md.
    timeout = "3600s"

    # Shared-pg socket mount (see tf/secrets.tf for the URL composition)
    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = ["jarvus-shared-postgres:us-east4:shared-pg"]
      }
    }

    scaling {
      min_instance_count = 1
      max_instance_count = 3
    }

    containers {
      image = var.backend_image

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        # Request-based billing with min=1 warm (2026-07 cost review): no cold
        # starts for the app, CPU allocated only while requests (incl. open SSE
        # streams) are in flight.
        cpu_idle = true
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }

      env {
        name  = "NODE_ENV"
        value = "production"
      }

      env {
        name = "DATABASE_URL"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.database_url.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "JWT_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.jwt_secret.secret_id
            version = "latest"
          }
        }
      }

      # Twilio Verify — presence of all three switches auth from the dev console
      # provider to real SMS (see routes/v1/auth.ts).
      env {
        name = "TWILIO_ACCOUNT_SID"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.twilio_account_sid.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "TWILIO_AUTH_TOKEN"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.twilio_auth_token.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "TWILIO_VERIFY_SERVICE_SID"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.twilio_verify_sid.secret_id
            version = "latest"
          }
        }
      }

      # Media bucket for signed-URL uploads (not a secret — a plain bucket name).
      env {
        name  = "MEDIA_BUCKET"
        value = google_storage_bucket.media.name
      }

      # CORS allow-list for browser clients. The v2 web app (prod + all path-based
      # branch previews) shares this one origin; native clients aren't CORS-gated.
      # See specs/api/conventions.md + behaviors/ci-cd.md.
      env {
        name  = "ALLOWED_ORIGINS"
        value = "https://v2.squadquest.app"
      }

      startup_probe {
        http_get {
          path = "/v1/health"
          port = 8080
        }
        initial_delay_seconds = 10
        period_seconds        = 5
        failure_threshold     = 6 # tolerate migrate-on-startup time
      }

      liveness_probe {
        http_get {
          path = "/v1/health"
          port = 8080
        }
        period_seconds = 30
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  # CI (v2-publish.yml) deploys new images via `gcloud run deploy --image`, so the
  # running image is owned by the deploy pipeline, not tf. tf still owns the rest
  # of the service config (secrets, VPC, scaling, probes); ignore image + the
  # client-name annotation gcloud stamps so `tofu plan` stays clean between deploys.
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      client,
      client_version,
    ]
  }

  depends_on = [
    google_secret_manager_secret_version.database_url,
    google_secret_manager_secret_version.jwt_secret,
    google_project_iam_member.cloudrun_secret_accessor,
  ]
}

# Public API — clients connect directly (auth is JWT at the app layer).
resource "google_cloud_run_v2_service_iam_member" "public" {
  project  = google_cloud_run_v2_service.backend.project
  location = google_cloud_run_v2_service.backend.location
  name     = google_cloud_run_v2_service.backend.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Custom domain (managed cert) for api.squadquest.app. squadquest.app ownership
# is verified in Google Webmaster Central; the mapping emits the rrdata for the
# api DNS record (wired in frontend.tf as google_dns_record_set.api).
resource "google_cloud_run_domain_mapping" "backend" {
  name     = var.api_domain
  location = google_cloud_run_v2_service.backend.location

  metadata {
    namespace = "squadquest-d8665"
  }

  spec {
    route_name = google_cloud_run_v2_service.backend.name
  }
}

output "backend_service_url" {
  value = google_cloud_run_v2_service.backend.uri
}
