# =============================================================================
# VPC networking — private path from Cloud Run to Cloud SQL
# =============================================================================
# Cloud SQL has no public IP; Cloud Run reaches it over a private VPC via a
# VPC Access connector. Mirrors the jarvus-hq topology.

resource "google_compute_network" "backend" {
  name                    = "squadquest-backend"
  auto_create_subnetworks = true

  depends_on = [google_project_service.backend]
}

# Reserved range for the Cloud SQL private-services peering.
resource "google_compute_global_address" "private_ip" {
  name          = "squadquest-backend-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.backend.id
}

resource "google_service_networking_connection" "private_vpc" {
  network                 = google_compute_network.backend.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip.name]
}

# Serverless VPC Access connector: Cloud Run -> private ranges (Cloud SQL).
resource "google_vpc_access_connector" "backend" {
  name          = "squadquest-backend"
  region        = "us-central1"
  network       = google_compute_network.backend.name
  ip_cidr_range = "10.8.0.0/28"

  min_instances = 2
  max_instances = 3

  depends_on = [google_project_service.backend]
}
