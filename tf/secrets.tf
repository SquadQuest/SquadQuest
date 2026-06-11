# =============================================================================
# Secret Manager — runtime secrets for the Cloud Run service
# =============================================================================
# DATABASE_URL (composed from the Cloud SQL private IP + generated password) and
# JWT_SECRET (generated; the env plugin requires >= 32 chars). The Cloud Run
# service reads these via secret_key_ref (wired in Phase 3 / cloudrun.tf).

data "google_project" "current" {}

# --- DATABASE_URL ------------------------------------------------------------
resource "google_secret_manager_secret" "database_url" {
  secret_id = "database-url"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "database_url" {
  secret      = google_secret_manager_secret.database_url.id
  secret_data = "postgres://${google_sql_user.backend.name}:${random_password.db_password.result}@${google_sql_database_instance.backend.private_ip_address}:5432/${google_sql_database.backend.name}"
}

# --- JWT_SECRET --------------------------------------------------------------
resource "random_password" "jwt_secret" {
  length  = 48
  special = false
}

resource "google_secret_manager_secret" "jwt_secret" {
  secret_id = "jwt-secret"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "jwt_secret" {
  secret      = google_secret_manager_secret.jwt_secret.id
  secret_data = random_password.jwt_secret.result
}

# --- Access: the default compute SA (Cloud Run's runtime identity) -----------
resource "google_project_iam_member" "cloudrun_secret_accessor" {
  project = "squadquest-d8665"
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}
