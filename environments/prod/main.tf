terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

locals {
  project_id = "overload-party-prod"
  region     = "asia-northeast1" # Tokyo
}

provider "google" {
  project = local.project_id
  region  = local.region
}

# ──────────────────────────────────────────────
# VPC Network
# ──────────────────────────────────────────────

resource "google_compute_network" "main" {
  name                    = "overload-party-network"
  project                 = local.project_id
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "main" {
  name          = "overload-party-subnet"
  project       = local.project_id
  region        = local.region
  network       = google_compute_network.main.id
  ip_cidr_range = "10.0.0.0/20"
}

# Private services access for Cloud SQL private IP
resource "google_compute_global_address" "private_ip" {
  name          = "overload-party-private-ip"
  project       = local.project_id
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

# ──────────────────────────────────────────────
# Cloud SQL (PostgreSQL)
# ──────────────────────────────────────────────

module "cloudsql" {
  source = "../../modules/cloudsql"

  project_id            = local.project_id
  region                = local.region
  tier                  = "db-g1-small" # upgrade as needed
  database_name         = "overload_party"
  network_id            = google_compute_network.main.self_link
  service_account_email = module.iam.service_account_email
  deletion_protection   = true
  ipv4_enabled          = false

  depends_on = [google_service_networking_connection.private]
}

# ──────────────────────────────────────────────
# IAM
# ──────────────────────────────────────────────

module "iam" {
  source = "../../modules/iam"

  project_id          = local.project_id
  service_account_id  = "overload-party-app"
  gke_project_id      = "keyandnotes-platform"
  k8s_namespace                   = "prod"
  k8s_service_account             = "game-server"
  terraform_service_account_email = "terraform-deployer@keyandnotes-platform.iam.gserviceaccount.com"
}

# No Cloud Scheduler for prod — Cloud SQL is always on.

# ──────────────────────────────────────────────
# Static Assets (card illustrations, stamps)
# ──────────────────────────────────────────────

module "static_assets" {
  source = "../../modules/static-assets"

  project_id = local.project_id
  region     = local.region
}

# ──────────────────────────────────────────────
# Outputs
# ──────────────────────────────────────────────

output "cloudsql_connection_name" {
  value = module.cloudsql.instance_connection_name
}

output "database_url_iam" {
  value     = module.cloudsql.database_url_iam
  sensitive = true
}

output "game_server_sa_email" {
  value = module.iam.service_account_email
}

output "assets_bucket_name" {
  value = module.static_assets.bucket_name
}

output "assets_bucket_url" {
  value = module.static_assets.bucket_url
}
