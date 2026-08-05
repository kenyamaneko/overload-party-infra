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

  # 対になる秘密鍵は Secret Manager の internal-auth-private-key に手動投入する。
  # 公開鍵は秘密ではないため平文で持つ。
  internal_auth_public_key = <<-EOT
    -----BEGIN PUBLIC KEY-----
    MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAxCGOgYNRn16Y+RnN1bDj
    LylY/IBM4R56n2SgUtB9qJdjY86aJVdX85QMGewkF1Dd2cP6o1p771v55sodH5Dk
    La0ypIgliRyMtDrUIpvnVV61httRjPMxVhEuhhnUFahx9LjkOToEc1cdpxCHwr5l
    UW9/t0wci4qDw4xOvaQtT4RHhgl5m/3s93lAflTdSBEwnirkkBLLuK5OpD0asgXq
    BSH3lTZ4H25fAHKMJk43gHKNLPYmW3AyvueabSzwlP6RAweltcdtbx+OAZ05Jsq4
    aPoVZMFt9H/8uWOP+syfNAgwc/mJxh3IrOrUUGYO3jy5PTEaHqv4tBHpXvK0krs/
    sQIDAQAB
    -----END PUBLIC KEY-----
  EOT

  cloudsql_instance_name = "overload-party-db"
  cloudsql_tier          = "db-f1-micro"

  # db-f1-micro はメモリが db-g1-small の 1/3 程度のため、同時接続を減らす向きに絞る。
  # Go の各サービスが張る接続数はこの値と接続プールの上限との積で決まる。battle は
  # 接続プールの上限を持たないため、この値だけでは決まらない。
  cloud_run_max_instance_count = 1
  database_name                = "overload_party"
  deletion_protection          = false
  ipv4_enabled                 = false

  firestore_location = "asia-northeast1"

  # 独自ドメイン配信のため FQDN = バケット名が必須 (Cloudflare CNAME → c.storage.googleapis.com、
  # GCS 側は Host ヘッダでバケットを解決するため名前が一致しないと 404 になる)
  assets_bucket_name    = "overload-party-assets-stg.keyandnotes.com"
  scenarios_bucket_name = "overload-party-stg-scenarios"
  newsfeed_bucket_name  = "overload-party-stg-newsfeed"

  master_data_bucket_name = "overload-party-stg-master-data"

  # stg は通常 PAUSED。prod リリース前検証時のみ `gcloud scheduler jobs resume` で
  # 一時的に有効化し、確認後に手動で pause に戻す運用。
  newsfeed_scheduler_paused = true

  enable_e2e            = true
  e2e_developer_members = ["user:kenya.m.amaoto@gmail.com"]

  gateway_allowed_origins = "capacitor://localhost,http://localhost"

  # 本来は Sandbox の実ストアを叩く設計だが、App Store Connect API キーが未発行で
  # shop が起動できないため暫定的に stub にしている。復帰は overload-party-shop#129。
  shop_iap_verifier      = "stub"
  shop_apple_environment = "Sandbox"

  support_cors_allowed_origins  = "https://overloadparty-stg.keyandnotes.com"
  support_slack_channel_id      = "CHANGEME_STG_SUPPORT_CHANNEL"
  support_sendgrid_from_address = "support-stg@keyandnotes.com"
  support_sendgrid_from_name    = "Overload Party Support (stg)"

  alert_email                         = var.alert_email
  alert_slack_notification_channel_id = ""

  billing_account_id = "019A0B-9A103A-B4C602"
  monthly_budget_jpy = 1000
}
