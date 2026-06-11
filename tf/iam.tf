# =============================================================================
# Backend deploy permissions for the v2-github-action CI service account
# =============================================================================
# The SA (defined in frontend.tf) already deploys the web build to GCS. These
# grants let the same SA build/push the server image and roll Cloud Run on a
# push to develop (the WIF provider already gates to refs/heads/develop).

locals {
  v2_ci_sa = google_service_account.v2_github.email
}

# Push images to Artifact Registry.
resource "google_project_iam_member" "v2_ci_ar_writer" {
  project = "squadquest-d8665"
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${local.v2_ci_sa}"
}

# Deploy / update the Cloud Run service.
resource "google_project_iam_member" "v2_ci_run_admin" {
  project = "squadquest-d8665"
  role    = "roles/run.admin"
  member  = "serviceAccount:${local.v2_ci_sa}"
}

# Act as the runtime (compute) SA when deploying Cloud Run.
resource "google_service_account_iam_member" "v2_ci_act_as_compute" {
  service_account_id = "projects/squadquest-d8665/serviceAccounts/${data.google_project.current.number}-compute@developer.gserviceaccount.com"
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${local.v2_ci_sa}"
}
