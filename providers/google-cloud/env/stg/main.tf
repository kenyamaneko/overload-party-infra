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

module "infra" {
  source = "../modules"

  project_id    = "overload-party-stg"
  region        = "asia-northeast1"
  k8s_namespace = "overload-party-stg"

  cloudsql_instance_name        = "overload-party-db"
  cloudsql_tier                 = "db-g1-small"
  database_name                 = "overload_party"
  deletion_protection           = false
  ipv4_enabled                  = false
  psc_allowed_consumer_projects = ["keyandnotes-platform"]

  firestore_location = "asia-northeast1"

  # 独自ドメイン配信のため FQDN = バケット名が必須 (Cloudflare CNAME → c.storage.googleapis.com、
  # GCS 側は Host ヘッダでバケットを解決するため名前が一致しないと 404 になる)
  assets_bucket_name    = "overload-party-assets-stg.keyandnotes.com"
  scenarios_bucket_name = "overload-party-stg-scenarios"
  newsfeed_bucket_name  = "overload-party-stg-newsfeed"

  migration_image = "asia-northeast1-docker.pkg.dev/keyandnotes-platform/overload-party/db-migrate:latest"
  newsfeed_image  = "asia-northeast1-docker.pkg.dev/keyandnotes-platform/overload-party/newsfeed:latest"

  # stg は通常 PAUSED。prod リリース前検証時のみ `gcloud scheduler jobs resume` で
  # 一時的に有効化し、確認後に手動で pause に戻す運用。
  newsfeed_scheduler_paused = true

  enable_e2e            = true
  e2e_developer_members = ["user:kenya.m.amaoto@gmail.com"]
}
