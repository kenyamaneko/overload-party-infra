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
  project = "overload-party-stg"
  region  = "asia-northeast1"
}

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

  env_name   = "stg"
  project_id = "overload-party-stg"
  region     = "asia-northeast1"

  cloudsql_instance_name = "overload-party-db"
  cloudsql_tier          = "db-g1-small"
  database_name          = "overload_party"
  deletion_protection    = false
  ipv4_enabled           = false

  firestore_location = "asia-northeast1"

  # 独自ドメイン配信のため FQDN = バケット名が必須 (Cloudflare CNAME → c.storage.googleapis.com、
  # GCS 側は Host ヘッダでバケットを解決するため名前が一致しないと 404 になる)
  assets_bucket_name    = "overload-party-assets-stg.keyandnotes.com"
  scenarios_bucket_name = "overload-party-stg-scenarios"
  newsfeed_bucket_name  = "overload-party-stg-newsfeed"

  # stg は通常 PAUSED。prod リリース前検証時のみ `gcloud scheduler jobs resume` で
  # 一時的に有効化し、確認後に手動で pause に戻す運用。
  newsfeed_scheduler_paused = true

  enable_e2e            = true
  e2e_developer_members = ["user:kenya.m.amaoto@gmail.com"]

  gateway_allowed_origins = "https://overloadparty-stg.keyandnotes.com,capacitor://localhost,http://localhost"

  shop_apple_environment = "Sandbox"

  support_cors_allowed_origins  = "https://overloadparty-stg.keyandnotes.com"
  support_slack_channel_id      = "CHANGEME_STG_SUPPORT_CHANNEL"
  support_sendgrid_from_address = "support-stg@keyandnotes.com"
  support_sendgrid_from_name    = "Overload Party Support (stg)"
}
