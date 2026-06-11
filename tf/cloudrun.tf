# =============================================================================
# Cloud Run — the v2 backend API service
# =============================================================================
# Containerized Fastify/Bun, VPC-connected to reach Cloud SQL over private IP,
# env from Secret Manager, min_instances=1 (warm — friendly to the planned
# SSE/LISTEN-NOTIFY realtime). Migrations run on container startup (see
# server/Dockerfile + src/migrate.ts).

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
    vpc_access {
      connector = google_vpc_access_connector.backend.id
      egress    = "PRIVATE_RANGES_ONLY"
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

# Custom domain (managed cert). DNS record added in frontend.tf's zone below.
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
