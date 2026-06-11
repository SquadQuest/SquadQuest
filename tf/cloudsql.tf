# =============================================================================
# Cloud SQL — production Postgres for the v2 backend
# =============================================================================
# POSTGRES_17 to match local dev (postgres:17-alpine). Private IP only (reached
# via the VPC connector); backups + PITR on; deletion-protected.

resource "google_sql_database_instance" "backend" {
  name             = "squadquest-v2"
  database_version = "POSTGRES_17"
  region           = "us-central1"

  settings {
    tier              = "db-f1-micro"
    availability_type = "ZONAL"
    edition           = "ENTERPRISE"

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = google_compute_network.backend.id
      enable_private_path_for_google_cloud_services = true
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
    }

    disk_size = 10
    disk_type = "PD_SSD"
  }

  # Guard rail: flip to false in a separate apply before any intentional destroy.
  deletion_protection = true

  depends_on = [google_service_networking_connection.private_vpc]
}

resource "google_sql_database" "backend" {
  name     = "squadquest_v2"
  instance = google_sql_database_instance.backend.name
}

resource "random_password" "db_password" {
  length  = 32
  special = false # avoid URL-encoding headaches in DATABASE_URL
}

resource "google_sql_user" "backend" {
  name     = "squadquest"
  instance = google_sql_database_instance.backend.name
  password = random_password.db_password.result
}
