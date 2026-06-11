# =============================================================================
# Frontend hosting (storybook + v2 web builds)
# DNS zone + records, GCS website buckets, GitHub-Actions deploy SAs + Workload
# Identity, and the shared HTTPS load balancer. Split out from main.tf.
# =============================================================================

# =============================================================================
# DNS Zone
# =============================================================================

resource "google_dns_managed_zone" "squadquest" {
  name     = "squadquest-app"
  dns_name = "squadquest.app."
}

# DNS records for the frontend LB
resource "google_dns_record_set" "storybook" {
  managed_zone = google_dns_managed_zone.squadquest.name
  name         = "storybook.squadquest.app."
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.frontend.address]
}

resource "google_dns_record_set" "v2" {
  managed_zone = google_dns_managed_zone.squadquest.name
  name         = "v2.squadquest.app."
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.frontend.address]
}

# GitHub Pages (apex domain)
resource "google_dns_record_set" "apex" {
  managed_zone = google_dns_managed_zone.squadquest.name
  name         = "squadquest.app."
  type         = "A"
  ttl          = 300
  # GitHub Pages IPs: https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site
  rrdatas = [
    "185.199.108.153",
    "185.199.109.153",
    "185.199.110.153",
    "185.199.111.153",
  ]
}

resource "google_dns_record_set" "www" {
  managed_zone = google_dns_managed_zone.squadquest.name
  name         = "www.squadquest.app."
  type         = "CNAME"
  ttl          = 300
  rrdatas      = ["squadquest.github.io."]
}

# GitHub Pages domain verification (org-level)
resource "google_dns_record_set" "github_pages_challenge_org" {
  managed_zone = google_dns_managed_zone.squadquest.name
  name         = "_github-pages-challenge-SquadQuest.squadquest.app."
  type         = "TXT"
  ttl          = 300
  rrdatas      = ["\"ca45149711193709b4658fe140f9d5\""]
}

# Google Search Console / Webmaster Central domain-ownership verification —
# unblocks the Cloud Run domain mapping for api.squadquest.app (see cloudrun.tf).
resource "google_dns_record_set" "google_site_verification" {
  managed_zone = google_dns_managed_zone.squadquest.name
  name         = "squadquest.app."
  type         = "TXT"
  ttl          = 300
  rrdatas      = ["\"google-site-verification=LpqfUAzbIdG1dc6hC-zK0jC-83MHKZpRZP5o1rZ1DHc\""]
}

# api.squadquest.app -> the Cloud Run domain mapping (google_cloud_run_domain_mapping.backend).
# CNAME target emitted by the mapping's status.resourceRecords.
resource "google_dns_record_set" "api" {
  managed_zone = google_dns_managed_zone.squadquest.name
  name         = "api.squadquest.app."
  type         = "CNAME"
  ttl          = 300
  rrdatas      = ["ghs.googlehosted.com."]
}

# Dev environment
resource "google_dns_record_set" "dev" {
  managed_zone = google_dns_managed_zone.squadquest.name
  name         = "dev.squadquest.app."
  type         = "CNAME"
  ttl          = 300
  rrdatas      = ["chris-devbox.phl.io."]
}

resource "google_dns_record_set" "supabase" {
  managed_zone = google_dns_managed_zone.squadquest.name
  name         = "supabase.squadquest.app."
  type         = "CNAME"
  ttl          = 300
  rrdatas      = ["chris-devbox.phl.io."]
}

resource "google_dns_record_set" "functions_dev" {
  managed_zone = google_dns_managed_zone.squadquest.name
  name         = "functions.dev.squadquest.app."
  type         = "CNAME"
  ttl          = 300
  rrdatas      = ["chris-devbox.phl.io."]
}

# Postmark email bounces
resource "google_dns_record_set" "pm_bounces" {
  managed_zone = google_dns_managed_zone.squadquest.name
  name         = "pm-bounces.squadquest.app."
  type         = "CNAME"
  ttl          = 300
  rrdatas      = ["pm.mtasv.net."]
}

# =============================================================================
# Storage Buckets
# =============================================================================

resource "google_storage_bucket" "storybook" {
  name                        = "storybook.squadquest.app"
  location                    = "US"
  uniform_bucket_level_access = true

  website {
    main_page_suffix = "index.html"
    not_found_page   = "index.html"
  }
}

resource "google_storage_bucket_iam_member" "storybook_public" {
  bucket = google_storage_bucket.storybook.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

resource "google_storage_bucket" "v2" {
  name                        = "v2.squadquest.app"
  location                    = "US"
  uniform_bucket_level_access = true

  website {
    main_page_suffix = "index.html"
    not_found_page   = "index.html"
  }
}

resource "google_storage_bucket_iam_member" "v2_public" {
  bucket = google_storage_bucket.v2.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# =============================================================================
# Service Accounts
# =============================================================================

resource "google_service_account" "storybook_github" {
  account_id   = "storybook-github-action"
  display_name = "storybook-github-action"
}

resource "google_service_account" "v2_github" {
  account_id   = "v2-github-action"
  display_name = "v2-github-action"
}

resource "google_storage_bucket_iam_member" "storybook_deploy" {
  bucket = google_storage_bucket.storybook.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.storybook_github.email}"
}

resource "google_storage_bucket_iam_member" "v2_deploy" {
  bucket = google_storage_bucket.v2.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.v2_github.email}"
}

# =============================================================================
# Workload Identity (GitHub Actions OIDC)
# =============================================================================

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions Pool"
}

resource "google_iam_workload_identity_pool_provider" "storybook" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "storybook-github-actions"
  display_name                       = "Storybook GitHub Action"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.actor"            = "assertion.actor"
  }

  attribute_condition = "assertion.repository == 'SquadQuest/SquadQuest' && assertion.ref=='refs/heads/develop'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_iam_workload_identity_pool_provider" "v2" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "v2-github-actions"
  display_name                       = "V2 GitHub Action"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.actor"            = "assertion.actor"
  }

  attribute_condition = "assertion.repository == 'SquadQuest/SquadQuest' && assertion.ref=='refs/heads/develop'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "storybook_workload_identity" {
  service_account_id = google_service_account.storybook_github.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/SquadQuest/SquadQuest"
}

resource "google_service_account_iam_member" "v2_workload_identity" {
  service_account_id = google_service_account.v2_github.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/SquadQuest/SquadQuest"
}

# =============================================================================
# Frontend Load Balancer (shared: storybook + v2)
# =============================================================================

resource "google_compute_global_address" "frontend" {
  name = "squadquest-frontend"
}

resource "google_compute_backend_bucket" "storybook" {
  name        = "storybook"
  bucket_name = google_storage_bucket.storybook.name
  enable_cdn  = false
}

resource "google_compute_backend_bucket" "v2" {
  name        = "v2"
  bucket_name = google_storage_bucket.v2.name
  enable_cdn  = false
}

resource "google_compute_url_map" "frontend" {
  name            = "squadquest-frontend"
  default_service = google_compute_backend_bucket.storybook.id

  host_rule {
    hosts        = ["storybook.squadquest.app"]
    path_matcher = "storybook"
  }

  host_rule {
    hosts        = ["v2.squadquest.app"]
    path_matcher = "v2"
  }

  path_matcher {
    name            = "storybook"
    default_service = google_compute_backend_bucket.storybook.id
  }

  path_matcher {
    name            = "v2"
    default_service = google_compute_backend_bucket.v2.id
  }
}

resource "google_compute_url_map" "frontend_redirect" {
  name = "squadquest-frontend-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_managed_ssl_certificate" "frontend" {
  name = "squadquest-frontend"

  managed {
    domains = [
      "storybook.squadquest.app",
      "v2.squadquest.app",
    ]
  }
}

resource "google_compute_target_https_proxy" "frontend" {
  name             = "squadquest-frontend-https"
  url_map          = google_compute_url_map.frontend.id
  ssl_certificates = [google_compute_managed_ssl_certificate.frontend.id]
}

resource "google_compute_target_http_proxy" "frontend_redirect" {
  name    = "squadquest-frontend-http"
  url_map = google_compute_url_map.frontend_redirect.id
}

resource "google_compute_global_forwarding_rule" "frontend_https" {
  name                  = "squadquest-frontend-https"
  target                = google_compute_target_https_proxy.frontend.id
  ip_address            = google_compute_global_address.frontend.id
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

resource "google_compute_global_forwarding_rule" "frontend_http" {
  name                  = "squadquest-frontend-http"
  target                = google_compute_target_http_proxy.frontend_redirect.id
  ip_address            = google_compute_global_address.frontend.id
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
