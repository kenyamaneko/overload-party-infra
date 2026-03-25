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
  project_id = "overload-party-dev"
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

  project_id                    = local.project_id
  region                        = local.region
  tier                          = "db-g1-small"
  database_name                 = "overload_party"
  network_id                    = module.network.network_self_link
  service_account_id            = "overload-party-app"
  gke_project_id                = "keyandnotes-platform"
  k8s_namespace                 = "dev"
  k8s_service_account           = "game-server"
  ipv4_enabled                  = false
  psc_allowed_consumer_projects = ["keyandnotes-platform"]

  depends_on = [module.network.service_networking_connection]
}

# ──────────────────────────────────────────────
# DB Auto-stop (Cloud Scheduler)
# ──────────────────────────────────────────────

module "db_autostop" {
  source = "../../modules/db-autostop"

  project_id        = local.project_id
  region            = local.region
  cloudsql_instance = "overload-party-db"
  stop_schedule     = "0 2 * * *" # 2:00 AM JST
}

# ──────────────────────────────────────────────
# DB Migration (Cloud Run Job)
# ──────────────────────────────────────────────

module "db_migration" {
  source = "../../modules/db-migration"

  project_id                   = local.project_id
  region                       = local.region
  migration_image              = "asia-northeast1-docker.pkg.dev/keyandnotes-platform/overload-party/db-migrate:latest"
  network                      = module.network.network_name
  subnetwork                   = module.network.subnetwork_name
  cloudsql_private_ip          = module.database.private_ip_address
  database_name                = "overload_party"
  deploy_service_account_email = "github-ci@keyandnotes-platform.iam.gserviceaccount.com"

  depends_on = [module.network.service_networking_connection]
}

# ──────────────────────────────────────────────
# Newsfeed Job
# ──────────────────────────────────────────────

module "newsfeed" {
  source = "../../modules/newsfeed"

  project_id          = local.project_id
  region              = local.region
  newsfeed_image      = "asia-northeast1-docker.pkg.dev/keyandnotes-platform/overload-party/newsfeed:latest"
  network             = module.network.network_name
  subnetwork          = module.network.subnetwork_name
  cloudsql_private_ip = module.database.private_ip_address

  depends_on = [module.network.service_networking_connection]
}

# ──────────────────────────────────────────────
# Game Assets (card illustrations, stamps, scenario art/music/SE/scripts)
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

output "newsfeed_job_name" {
  value = module.newsfeed.newsfeed_job_name
}

output "newsfeed_gcs_bucket" {
  value = module.newsfeed.gcs_bucket_name
}

output "newsfeed_sa_email" {
  value = module.newsfeed.newsfeed_sa_email
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

output "cloudsql_psc_service_attachment" {
  value = module.database.psc_service_attachment_link
}

output "cloudsql_dns_name" {
  value = module.database.dns_name
}
