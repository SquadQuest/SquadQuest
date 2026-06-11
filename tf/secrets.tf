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

# --- Twilio Verify (SMS OTP) -------------------------------------------------
# Reuses the v1 SquadQuest Verify service. These are CONTAINERS only — values
# come from outside GCP (the Twilio Console) and are set by hand so they never
# pass through tf/git/chat:
#   printf 'ACxxxx…' | gcloud secrets versions add twilio-account-sid --project=squadquest-d8665 --data-file=-
#   printf '<token>' | gcloud secrets versions add twilio-auth-token  --project=squadquest-d8665 --data-file=-
#   printf 'VAxxxx…' | gcloud secrets versions add twilio-verify-sid  --project=squadquest-d8665 --data-file=-
# Wiring into Cloud Run + a TwilioVerifyOtpProvider is the v2-sms-otp work.
resource "google_secret_manager_secret" "twilio_account_sid" {
  secret_id = "twilio-account-sid"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "twilio_auth_token" {
  secret_id = "twilio-auth-token"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "twilio_verify_sid" {
  secret_id = "twilio-verify-sid"
  replication {
    auto {}
  }
}

# --- Access: the default compute SA (Cloud Run's runtime identity) -----------
# Project-level binding — covers database-url, jwt-secret, and the twilio-* secrets.
resource "google_project_iam_member" "cloudrun_secret_accessor" {
  project = "squadquest-d8665"
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}
