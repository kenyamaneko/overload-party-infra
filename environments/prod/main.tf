terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
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

provider "google-beta" {
  project = local.project_id
  region  = local.region
}

# ──────────────────────────────────────────────
# Network
# ──────────────────────────────────────────────

module "network" {
  source = "../../modules/network"

  project_id = local.project_id
  region     = local.region
}

# ──────────────────────────────────────────────
# Database (Cloud SQL PostgreSQL)
# ──────────────────────────────────────────────

module "database" {
  source = "../../modules/database"

  project_id          = local.project_id
  region              = local.region
  tier                = "db-g1-small" # upgrade as needed
  database_name       = "overload_party"
  network_id          = module.network.network_self_link
  service_account_id  = "overload-party-app"
  gke_project_id      = "keyandnotes-platform"
  k8s_namespace       = "prod"
  k8s_service_account = "game-server"
  deletion_protection = true
  ipv4_enabled        = false

  depends_on = [module.network.service_networking_connection]
}

# No Cloud Scheduler for prod — Cloud SQL is always on.

# ──────────────────────────────────────────────
# Game Assets (card illustrations, stamps)
# ──────────────────────────────────────────────

module "assets" {
  source = "../../modules/assets"

  project_id = local.project_id
  region     = local.region
}

# ──────────────────────────────────────────────
# Outputs
# ──────────────────────────────────────────────

output "cloudsql_connection_name" {
  value = module.database.instance_connection_name
}

output "database_url_iam" {
  value     = module.database.database_url_iam
  sensitive = true
}

output "game_server_sa_email" {
  value = module.database.service_account_email
}

output "assets_site_id" {
  value = module.assets.site_id
}

output "assets_url" {
  value = module.assets.default_url
}

output "assets_bucket_name" {
  value = module.assets.bucket_name
}

output "assets_bucket_url" {
  value = module.assets.bucket_url
}
