# =============================================================================
# Media storage — user-supplied images (profile/community photos, attachments)
# =============================================================================
# Public-read bucket with unguessable (uuid) keys: serialized resources return a
# plain public URL, no per-request signing. Uploads use V4 signed PUT URLs minted
# by the Cloud Run runtime SA (keyless, via IAM signBlob). See specs/api/uploads.md
# + conventions.md §Storage.

resource "google_storage_bucket" "media" {
  name                        = "squadquest-v2-media"
  location                    = "us-central1"
  uniform_bucket_level_access = true

  # Browser uploads via signed PUT need CORS for the app origins.
  cors {
    origin          = ["https://v2.squadquest.app", "http://localhost:*"]
    method          = ["GET", "PUT"]
    response_header = ["Content-Type"]
    max_age_seconds = 3600
  }
}

# World-readable objects (keys are unguessable uuids).
resource "google_storage_bucket_iam_member" "media_public" {
  bucket = google_storage_bucket.media.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# The Cloud Run runtime SA reads/writes objects (signed-URL minting is done with
# its own identity; this also lets it manage objects directly if ever needed).
resource "google_storage_bucket_iam_member" "media_runtime_admin" {
  bucket = google_storage_bucket.media.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}

# The CI deploy SA publishes built APKs to apk/ (v2-publish.yml v2-apk job).
# It already has objectAdmin on the frontend buckets; the media bucket needs its
# own grant. See specs/behaviors/ci-cd.md.
resource "google_storage_bucket_iam_member" "media_ci_apk_writer" {
  bucket = google_storage_bucket.media.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.v2_github.email}"
}

# Keyless V4 signing: the runtime SA must be able to sign blobs AS ITSELF
# (@google-cloud/storage falls back to the IAM signBlob API when no private key
# is present, which is the case on Cloud Run with ADC).
resource "google_service_account_iam_member" "media_signer" {
  service_account_id = "projects/squadquest-d8665/serviceAccounts/${data.google_project.current.number}-compute@developer.gserviceaccount.com"
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}
