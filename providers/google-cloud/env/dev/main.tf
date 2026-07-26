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
  project = "overload-party-dev"
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

  env_name      = "dev"
  project_id    = "overload-party-dev"
  region        = "asia-northeast1"
  k8s_namespace = "overload-party-dev"

  psc_consumer_project_id = "keyandnotes-platform"
  psc_consumer_network    = "default"

  cloudsql_instance_name        = "overload-party-db"
  cloudsql_tier                 = "db-g1-small"
  database_name                 = "overload_party"
  deletion_protection           = false
  ipv4_enabled                  = false
  psc_allowed_consumer_projects = ["keyandnotes-platform"]

  firestore_location = "asia-northeast1"

  # 独自ドメイン配信のため FQDN = バケット名が必須 (Cloudflare CNAME → c.storage.googleapis.com、
  # GCS 側は Host ヘッダでバケットを解決するため名前が一致しないと 404 になる)
  assets_bucket_name    = "overload-party-assets-dev.keyandnotes.com"
  scenarios_bucket_name = "overload-party-dev-scenarios"
  newsfeed_bucket_name  = "overload-party-dev-newsfeed"

  # dev は Cloud Scheduler を形式的に配置するのみ (cron は設定するが常時 PAUSED)。
  # 手動実行は `gcloud run jobs execute newsfeed-job` を使う。
  newsfeed_scheduler_paused = true

  enable_e2e            = true
  e2e_developer_members = ["user:kenya.m.amaoto@gmail.com"]

  gateway_allowed_origins = "http://localhost:3000,capacitor://localhost,http://localhost"

  # 通知チャンネルの作成手順は infra#79 を参照する (state に秘密情報を持ち込まないため Terraform ではなく Cloud Monitoring 上で作る)
  gateway_alert_notification_channel_ids = []

  shop_apple_environment = "Sandbox"

  support_cors_allowed_origins  = "http://localhost:3000"
  support_slack_channel_id      = "CHANGEME_DEV_SUPPORT_CHANNEL"
  support_sendgrid_from_address = "support-dev@keyandnotes.com"
  support_sendgrid_from_name    = "Overload Party Support (dev)"
}

