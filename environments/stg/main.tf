terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
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

module "vpc" {
  source = "../../modules/vpc"

  project_id = local.project_id
  region     = local.region
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
  network_id            = module.vpc.network_self_link
  service_account_email = module.iam.service_account_email
  ipv4_enabled          = false

  depends_on = [module.vpc.service_networking_connection]
}

# ──────────────────────────────────────────────
# IAM
# ──────────────────────────────────────────────

module "iam" {
  source = "../../modules/iam"

  project_id                   = local.project_id
  service_account_id           = "overload-party-app"
  gke_project_id               = "keyandnotes-platform"
  k8s_namespace                = "stg"
  k8s_service_account          = "game-server"
  deploy_service_account_email    = "github-ci@keyandnotes-platform.iam.gserviceaccount.com"
  terraform_service_account_email = "terraform-deployer@keyandnotes-platform.iam.gserviceaccount.com"
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
# Cloud Run Job (DB Migration)
# ──────────────────────────────────────────────

module "migration_job" {
  source = "../../modules/migration-job"

  project_id            = local.project_id
  region                = local.region
  migration_image       = "asia-northeast1-docker.pkg.dev/keyandnotes-platform/overload-party/db-migrate:latest"
  network               = module.vpc.network_name
  subnetwork            = module.vpc.subnetwork_name
  cloudsql_private_ip          = module.cloudsql.private_ip_address
  database_name                = "overload_party"
  deploy_service_account_email = "github-ci@keyandnotes-platform.iam.gserviceaccount.com"

  depends_on = [module.vpc.service_networking_connection]
}

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

output "cloudsql_private_ip" {
  value = module.cloudsql.private_ip_address
}

output "database_url_iam" {
  value     = module.cloudsql.database_url_iam
  sensitive = true
}

output "game_server_sa_email" {
  value = module.iam.service_account_email
}

output "migration_job_name" {
  value = module.migration_job.job_name
}

output "assets_bucket_name" {
  value = module.static_assets.bucket_name
}

output "assets_bucket_url" {
  value = module.static_assets.bucket_url
}
