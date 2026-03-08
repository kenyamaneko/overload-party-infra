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
  project_id = "overload-party-dev"
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
  ipv4_enabled          = false

  depends_on = [google_service_networking_connection.private]
}

# ──────────────────────────────────────────────
# IAM
# ──────────────────────────────────────────────

module "iam" {
  source = "../../modules/iam"

  project_id                   = local.project_id
  service_account_id           = "overload-party-app"
  gke_project_id               = "overload-party-shared"
  k8s_namespace                = "dev"
  k8s_service_account          = "game-server"
  deploy_service_account_email = "github-ci@overload-party-shared.iam.gserviceaccount.com"
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

  project_id                   = local.project_id
  region                       = local.region
  migration_image              = "asia-northeast1-docker.pkg.dev/overload-party-shared/overload-party/db-migrate:latest"
  network                      = google_compute_network.main.name
  subnetwork                   = google_compute_subnetwork.main.name
  cloudsql_private_ip          = module.cloudsql.private_ip_address
  database_name                = "overload_party"
  deploy_service_account_email = "github-ci@overload-party-shared.iam.gserviceaccount.com"

  depends_on = [google_service_networking_connection.private]
}

# ──────────────────────────────────────────────
# Newsfeed Job
# ──────────────────────────────────────────────

module "newsfeed" {
  source = "../../modules/newsfeed"

  project_id          = local.project_id
  region              = local.region
  newsfeed_image      = "asia-northeast1-docker.pkg.dev/overload-party-shared/overload-party/newsfeed:latest"
  network             = google_compute_network.main.name
  subnetwork          = google_compute_subnetwork.main.name
  cloudsql_private_ip = module.cloudsql.private_ip_address

  depends_on = [google_service_networking_connection.private]
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

output "newsfeed_job_name" {
  value = module.newsfeed.newsfeed_job_name
}

output "newsfeed_gcs_bucket" {
  value = module.newsfeed.gcs_bucket_name
}

output "newsfeed_sa_email" {
  value = module.newsfeed.newsfeed_sa_email
}

output "assets_bucket_name" {
  value = module.static_assets.bucket_name
}

output "assets_bucket_url" {
  value = module.static_assets.bucket_url
}
