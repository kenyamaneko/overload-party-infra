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

module "env" {
  source = "../modules"

  project_id    = "overload-party-prod"
  region        = "asia-northeast1"
  k8s_namespace = "overload-party-prod"

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
}
