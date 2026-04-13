terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = "overload-party-dev"
  region  = "asia-northeast1"
}

module "infra" {
  source = "../../modules"

  project_id    = "overload-party-dev"
  region        = "asia-northeast1"
  k8s_namespace = "overload-party-dev"

  # Cloud SQL
  cloudsql_instance_name = "overload-party-db"
  cloudsql_tier          = "db-g1-small"
  database_name          = "overload_party"
  deletion_protection    = false
  ipv4_enabled           = false
  # PSC は dev のみ有効化（k8s 環境からの cross-project 接続テスト用）
  psc_allowed_consumer_projects = ["keyandnotes-platform"]

  # Firestore
  firestore_location = "asia-northeast1"

  # GCS バケット名（グローバル一意。env 名サフィックスで衝突を回避）
  assets_bucket_name    = "overload-party-assets-dev.keyandnotes.com"
  scenarios_bucket_name = "overload-party-dev-scenarios"
  newsfeed_bucket_name  = "overload-party-dev-newsfeed"

  # Optional 機能（dev は migration / newsfeed どちらも有効）
  deploy_sa                    = var.deploy_sa
  migration_image              = "asia-northeast1-docker.pkg.dev/keyandnotes-platform/overload-party/db-migrate:latest"
  deploy_service_account_email = "github-ci@keyandnotes-platform.iam.gserviceaccount.com"
  enable_newsfeed              = true
  newsfeed_image               = "asia-northeast1-docker.pkg.dev/keyandnotes-platform/overload-party/newsfeed:latest"
}

# ──────────────────────────────────────────────
# 出力
# ──────────────────────────────────────────────

output "cloudsql_connection_name" {
  value = module.infra.cloudsql_connection_name
}

output "cloudsql_private_ip" {
  value = module.infra.cloudsql_private_ip
}

output "database_url_iam" {
  value     = module.infra.database_url_iam
  sensitive = true
}

output "game_server_sa_email" {
  value = module.infra.game_server_sa_email
}

output "migration_job_name" {
  value = module.infra.migration_job_name
}

output "newsfeed_job_name" {
  value = module.infra.newsfeed_job_name
}

output "newsfeed_gcs_bucket" {
  value = module.infra.newsfeed_gcs_bucket
}

output "newsfeed_sa_email" {
  value = module.infra.newsfeed_sa_email
}

output "assets_bucket_name" {
  value = module.infra.assets_bucket_name
}

output "assets_bucket_url" {
  value = module.infra.assets_bucket_url
}

output "scenarios_bucket_name" {
  value = module.infra.scenarios_bucket_name
}

output "scenarios_bucket_url" {
  value = module.infra.scenarios_bucket_url
}

output "cloudsql_psc_service_attachment" {
  value = module.infra.cloudsql_psc_service_attachment
}

output "cloudsql_dns_name" {
  value = module.infra.cloudsql_dns_name
}

output "matchmaking_events_topic" {
  value = module.infra.matchmaking_events_topic
}

output "matchmaking_events_subscription" {
  value = module.infra.matchmaking_events_subscription
}
