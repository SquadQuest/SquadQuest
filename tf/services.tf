# =============================================================================
# Enabled APIs
# =============================================================================
# Backend-infra needs these turned on. `disable_on_destroy = false` so a
# `tofu destroy` never disables an API that v1 / Firebase still rely on.
#
# (Many other APIs are enabled on this project from the v1/Firebase footprint —
#  fcm, firebase, identitytoolkit, etc. Those are imported in v1-firebase.tf so
#  state reflects reality; this block is the set the v2 backend stack requires.)

locals {
  backend_apis = [
    "run.googleapis.com",               # Cloud Run
    "sqladmin.googleapis.com",          # Cloud SQL
    "secretmanager.googleapis.com",     # Secret Manager
    "artifactregistry.googleapis.com",  # Artifact Registry (server image)
    "vpcaccess.googleapis.com",         # Cloud Run -> VPC connector
    "servicenetworking.googleapis.com", # Cloud SQL private-IP peering
    "compute.googleapis.com",           # VPC / networking (already on)
  ]
}

resource "google_project_service" "backend" {
  for_each = toset(local.backend_apis)

  service            = each.value
  disable_on_destroy = false
}
