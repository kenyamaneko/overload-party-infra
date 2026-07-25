terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

provider "google" {
  project = "overload-party-prod"
  region  = "asia-northeast1"
}

# PSC エンドポイント (IP / DNS) は consumer 側 VPC (keyandnotes-platform) に書き込む必要があるため alias で参照する
provider "google" {
  alias   = "platform"
  project = "keyandnotes-platform"
  region  = "asia-northeast1"
}

module "env" {
  source = "../modules"

  providers = {
    google.platform = google.platform
  }

  env_name      = "prod"
  project_id    = "overload-party-prod"
  region        = "asia-northeast1"
  k8s_namespace = "overload-party-prod"

  psc_consumer_project_id = "keyandnotes-platform"
  psc_consumer_network    = "default"

  cloudsql_instance_name        = "overload-party-db"
  cloudsql_tier                 = "db-g1-small"
  database_name                 = "overload_party"
  deletion_protection           = true
  ipv4_enabled                  = false
  psc_allowed_consumer_projects = ["keyandnotes-platform"]

  firestore_location = "asia-northeast1"

  # 独自ドメイン配信のため FQDN = バケット名が必須 (Cloudflare CNAME → c.storage.googleapis.com、
  # GCS 側は Host ヘッダでバケットを解決するため名前が一致しないと 404 になる)
  assets_bucket_name    = "overload-party-assets.keyandnotes.com"
  scenarios_bucket_name = "overload-party-prod-scenarios"
  newsfeed_bucket_name  = "overload-party-prod-newsfeed"

  # prod のみ Cloud Scheduler を有効化。2 時間周期で Cloud Run Job を起動する。
  newsfeed_scheduler_paused = false

  enable_e2e            = false
  e2e_developer_members = []

  gateway_machine_type    = "e2-small"
  gateway_use_static_ip   = true
  gateway_allowed_origins = "https://overloadparty-prod.keyandnotes.com,capacitor://localhost,http://localhost"

  shop_apple_environment = "Production"

  support_cors_allowed_origins  = "https://overloadparty-prod.keyandnotes.com"
  support_slack_channel_id      = "CHANGEME_PROD_SUPPORT_CHANNEL"
  support_sendgrid_from_address = "support@keyandnotes.com"
  support_sendgrid_from_name    = "Overload Party Support"

  artifact_registry_project_id    = "keyandnotes-platform"
  artifact_registry_location      = "asia-northeast1"
  artifact_registry_repository_id = "overload-party"
}
