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
  source = "../modules"

  project_id    = "overload-party-dev"
  region        = "asia-northeast1"
  k8s_namespace = "overload-party-dev"

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

  migration_image = "asia-northeast1-docker.pkg.dev/keyandnotes-platform/overload-party/db-migrate:latest"
  newsfeed_image  = "asia-northeast1-docker.pkg.dev/keyandnotes-platform/overload-party/newsfeed:latest"

  # dev は Cloud Scheduler を形式的に配置するのみ (cron は設定するが常時 PAUSED)。
  # 手動実行は `gcloud run jobs execute newsfeed-job` を使う。
  newsfeed_scheduler_paused = true
}

