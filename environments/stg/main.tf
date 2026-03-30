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
  project_id = "overload-party-stg"
  region     = "asia-northeast1" # Tokyo
  deploy_sa  = "serviceAccount:github-deploy@keyandnotes-platform.iam.gserviceaccount.com"
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
  tier                = "db-g1-small"
  database_name       = "overload_party"
  network_id          = module.network.network_self_link
  service_account_id  = "overload-party-app"
  gke_project_id      = "keyandnotes-platform"
  k8s_namespace       = "stg"
  k8s_service_account = "game-server"
  ipv4_enabled        = false

  depends_on = [module.network.service_networking_connection]
}

# ──────────────────────────────────────────────
# Cloud SQL 停止権限 (nightly-shutdown workflow 用)
# github-deploy SA は k8s リポ (modules/ci-cd) で管理。
# ここでは本プロジェクトでの操作権限のみ付与。
# ──────────────────────────────────────────────

resource "google_project_iam_member" "deploy_cloudsql_editor" {
  project = local.project_id
  role    = "roles/cloudsql.editor"
  member  = local.deploy_sa
}

# ──────────────────────────────────────────────
# DB Migration (Cloud Run Job)
# ──────────────────────────────────────────────

module "db_migration" {
  source = "../../modules/db-migration"

  project_id            = local.project_id
  region                = local.region
  migration_image       = "asia-northeast1-docker.pkg.dev/keyandnotes-platform/overload-party/db-migrate:latest"
  network               = module.network.network_name
  subnetwork            = module.network.subnetwork_name
  cloudsql_private_ip          = module.database.private_ip_address
  database_name                = "overload_party"
  deploy_service_account_email = "github-ci@keyandnotes-platform.iam.gserviceaccount.com"

  depends_on = [module.network.service_networking_connection]
}

# ──────────────────────────────────────────────
# Game Assets (card illustrations, stamps)
# ──────────────────────────────────────────────

module "assets" {
  source = "../../modules/assets"

  project_id   = local.project_id
  region       = local.region
  asset_domain = "overload-party-assets-stg.keyandnotes.com"
}

# ──────────────────────────────────────────────
# Outputs
# ──────────────────────────────────────────────

output "cloudsql_connection_name" {
  value = module.database.instance_connection_name
}

output "cloudsql_private_ip" {
  value = module.database.private_ip_address
}

output "database_url_iam" {
  value     = module.database.database_url_iam
  sensitive = true
}

output "game_server_sa_email" {
  value = module.database.service_account_email
}

output "migration_job_name" {
  value = module.db_migration.job_name
}

output "assets_bucket_name" {
  value = module.assets.assets_bucket_name
}

output "assets_bucket_url" {
  value = module.assets.assets_bucket_url
}

output "scenarios_bucket_name" {
  value = module.assets.scenarios_bucket_name
}

output "scenarios_bucket_url" {
  value = module.assets.scenarios_bucket_url
}
