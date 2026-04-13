variable "project_id" {
  description = "Google Cloud プロジェクト ID"
  type        = string
}

variable "region" {
  description = "Google Cloud リージョン"
  type        = string
}

locals {
  network_name = "overload-party-network"
  subnet_name  = "overload-party-subnet"
  subnet_cidr  = "10.0.0.0/20"
}

# ──────────────────────────────────────────────
# API 有効化
# ──────────────────────────────────────────────

resource "google_project_service" "servicenetworking" {
  project            = var.project_id
  service            = "servicenetworking.googleapis.com"
  disable_on_destroy = false
}

# ──────────────────────────────────────────────
# ネットワーク
# ──────────────────────────────────────────────

resource "google_compute_network" "main" {
  name                    = local.network_name
  project                 = var.project_id
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "main" {
  name          = local.subnet_name
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.main.id
  ip_cidr_range = local.subnet_cidr
}

resource "google_compute_global_address" "private_ip" {
  name          = "overload-party-private-ip"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.main.id
}

resource "google_service_networking_connection" "private" {
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip.name]
}

output "network_self_link" {
  value = google_compute_network.main.self_link
}

output "network_name" {
  value = google_compute_network.main.name
}

output "subnetwork_name" {
  value = google_compute_subnetwork.main.name
}

output "service_networking_connection" {
  description = "Service networking connection (use in depends_on)"
  value       = google_service_networking_connection.private
}
