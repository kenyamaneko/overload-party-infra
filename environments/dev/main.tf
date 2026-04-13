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

  project_id                    = "overload-party-dev"
  k8s_namespace                 = "overload-party-dev"
  asset_domain                  = "overload-party-assets-dev.keyandnotes.com"
  psc_allowed_consumer_projects = ["keyandnotes-platform"]
  deploy_sa                     = var.deploy_sa
  migration_image               = "asia-northeast1-docker.pkg.dev/keyandnotes-platform/overload-party/db-migrate:latest"
  deploy_service_account_email  = "github-ci@keyandnotes-platform.iam.gserviceaccount.com"
  enable_newsfeed               = true
  newsfeed_image                = "asia-northeast1-docker.pkg.dev/keyandnotes-platform/overload-party/newsfeed:latest"
}

# ──────────────────────────────────────────────
# ステート移行
# ──────────────────────────────────────────────

# service_accounts モジュール抽出 (既存)
moved {
  from = google_service_account.services
  to   = module.infra.module.service_accounts.google_service_account.accounts
}

moved {
  from = google_service_account_iam_member.services_workload_identity
  to   = module.infra.module.service_accounts.google_service_account_iam_member.workload_identity
}

# newsfeed GSA 抽出 (旧 module.newsfeed 内)
moved {
  from = module.newsfeed.google_service_account.newsfeed
  to   = module.infra.google_service_account.newsfeed[0]
}

# newsfeed SQL ユーザー (旧環境ルートのスタンドアロン)
moved {
  from = google_sql_user.newsfeed_iam
  to   = module.infra.module.database.google_sql_user.service_iam_users["newsfeed"]
}

# 全モジュールを module.infra に統合
moved {
  from = module.network
  to   = module.infra.module.network
}

moved {
  from = module.database
  to   = module.infra.module.database
}

moved {
  from = module.service_accounts
  to   = module.infra.module.service_accounts
}

moved {
  from = module.pubsub
  to   = module.infra.module.pubsub
}

moved {
  from = module.db_migration
  to   = module.infra.module.db_migration[0]
}

moved {
  from = module.newsfeed
  to   = module.infra.module.newsfeed[0]
}

moved {
  from = module.assets
  to   = module.infra.module.assets
}

# スタンドアロンリソース → module.infra
moved {
  from = google_project_iam_member.deploy_cloudsql_editor
  to   = module.infra.google_project_iam_member.deploy_cloudsql_editor[0]
}

moved {
  from = google_service_account.newsfeed
  to   = module.infra.google_service_account.newsfeed[0]
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
