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
  project = "overload-party-prod"
  region  = "asia-northeast1"
}

module "infra" {
  source = "../../modules"

  project_id          = "overload-party-prod"
  k8s_namespace       = "overload-party-prod"
  asset_domain        = "overload-party-assets.keyandnotes.com"
  deletion_protection = true
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
  from = module.assets
  to   = module.infra.module.assets
}

# ──────────────────────────────────────────────
# 出力
# ──────────────────────────────────────────────

output "cloudsql_connection_name" {
  value = module.infra.cloudsql_connection_name
}

output "database_url_iam" {
  value     = module.infra.database_url_iam
  sensitive = true
}

output "game_server_sa_email" {
  value = module.infra.game_server_sa_email
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

output "matchmaking_events_topic" {
  value = module.infra.matchmaking_events_topic
}

output "matchmaking_events_subscription" {
  value = module.infra.matchmaking_events_subscription
}
