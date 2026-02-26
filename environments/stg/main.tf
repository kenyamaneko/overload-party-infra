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
  project_id = "overload-party-stg"
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
  tier                  = "db-g1-small"
  database_name         = "overload_party"
  network_id            = google_compute_network.main.self_link
  service_account_email = module.iam.service_account_email

  depends_on = [google_service_networking_connection.private]
}

# ──────────────────────────────────────────────
# IAM
# ──────────────────────────────────────────────

module "iam" {
  source = "../../modules/iam"

  project_id          = local.project_id
  service_account_id  = "overload-party-server"
  gke_project_id      = "overload-party-shared"
  k8s_namespace       = "stg"
  k8s_service_account = "game-server"
}

# ──────────────────────────────────────────────
# Cloud Scheduler (Cloud SQL auto-stop)
# ──────────────────────────────────────────────

module "scheduler" {
  source = "../../modules/scheduler"

  project_id        = local.project_id
  region            = local.region
  cloudsql_instance = "overload-party-db"
  stop_schedule     = "0 2 * * *" # 2:00 AM JST
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
