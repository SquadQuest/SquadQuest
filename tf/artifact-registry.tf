# =============================================================================
# Artifact Registry — Docker repo for the v2 backend image
# =============================================================================
resource "google_artifact_registry_repository" "backend" {
  location      = "us-central1"
  repository_id = "squadquest-backend"
  format        = "DOCKER"
  description   = "v2 backend (Fastify/Bun) container images"

  depends_on = [google_project_service.backend]
}
