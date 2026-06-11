# =============================================================================
# v1 footprint (imported, not created)
# =============================================================================
# v1 still ships to production (app stores + squadquest.app) from this project's
# Firebase + CI infra. These resources were created out-of-band (Firebase console
# / earlier CI setup); they're imported here so `tofu plan` reflects reality and
# nothing here is accidentally destroyed. Do NOT recreate — adopt via import.
#
# Deliberately NOT managed here: the `firebase-adminsdk-755ie@` account is a
# Google-managed service agent (auto-created, holds firebase.sdkAdminServiceAgent).
# Importing service agents is an anti-pattern — tofu can't create/destroy them and
# it only adds plan noise. Left out by design.

# --- v1 GitHub Actions CI service account (user-created) ---------------------
resource "google_service_account" "v1_github_action" {
  account_id   = "github-action-812828867"
  display_name = "GitHub Actions (SquadQuest/SquadQuest)"
  description  = "A service account with permission to deploy to Play Console and Firebase"
}

locals {
  # The v1 CI SA's existing project roles — adopted as-is.
  v1_ci_roles = [
    "roles/cloudfunctions.developer",
    "roles/firebaseauth.admin",
    "roles/firebasehosting.admin",
    "roles/run.viewer",
    "roles/serviceusage.apiKeysViewer",
    "roles/serviceusage.serviceUsageConsumer",
  ]
}

resource "google_project_iam_member" "v1_ci" {
  for_each = toset(local.v1_ci_roles)

  project = "squadquest-d8665"
  role    = each.value
  member  = "serviceAccount:${google_service_account.v1_github_action.email}"
}

# --- v1 / Firebase enabled APIs ----------------------------------------------
# Acknowledged so tf reflects the project's real API surface. disable_on_destroy
# = false (never disable a v1-critical API). v2 will reuse fcm.* for push.
locals {
  v1_firebase_apis = [
    "androidpublisher.googleapis.com",
    "fcm.googleapis.com",
    "fcmregistrations.googleapis.com",
    "firebase.googleapis.com",
    "firebaseappdistribution.googleapis.com",
    "firebasedynamiclinks.googleapis.com",
    "firebasehosting.googleapis.com",
    "firebaseinstallations.googleapis.com",
    "firebaseremoteconfig.googleapis.com",
    "firebaseremoteconfigrealtime.googleapis.com",
    "firebaserules.googleapis.com",
    "identitytoolkit.googleapis.com",
    "mobilecrashreporting.googleapis.com",
    "securetoken.googleapis.com",
    "testing.googleapis.com",
  ]
}

resource "google_project_service" "v1_firebase" {
  for_each = toset(local.v1_firebase_apis)

  service            = each.value
  disable_on_destroy = false
}
