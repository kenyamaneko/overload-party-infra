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

  env_name   = "prod"
  project_id = "overload-party-prod"
  region     = "asia-northeast1"

  # 対になる秘密鍵は Secret Manager の internal-auth-private-key に手動投入する。
  # 公開鍵は秘密ではないため平文で持つ。
  internal_auth_public_key = <<-EOT
    -----BEGIN PUBLIC KEY-----
    MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEArp+bNRR26B+ugc1WlMap
    1SoLg3VidioO+nVDAlzeCBw601yWIntO5Zn8mnvpO3Ce3JouH1N6fSDF7gaKjvlo
    309CbfBjiGm+tVWmvn6c27zXNTiXQH6yJcCJs0/cP4HLG35f8leY8KBQ0KxNIrh2
    mtA4YmQxaASx9zO764VOkMmkTusOBPMsI4pbZm+QAsk7ipHeWnQsEs7NKgEWlfg+
    svDC9bEnfc3LyZDdHoWwzCbZqR5PTBnBPqfYqHdyi+XoeFxQtLqQGNvxBQcTGQNw
    zTR5VQiTuUXwnYWOtE5ekJzfOa2zx7+xxCdCW1kQ7111xo8wVYBtNneeup9qSthj
    TwIDAQAB
    -----END PUBLIC KEY-----
  EOT

  cloudsql_instance_name = "overload-party-db"
  cloudsql_tier          = "db-f1-micro"

  # db-f1-micro はメモリが db-g1-small の 1/3 程度のため、同時接続を減らす向きに絞る。
  # Go の各サービスが張る接続数はこの値と接続プールの上限との積で決まる。battle は
  # 接続プールの上限を持たないため、この値だけでは決まらない。
  cloud_run_max_instance_count = 1
  database_name                = "overload_party"
  deletion_protection          = true
  ipv4_enabled                 = false

  firestore_location = "asia-northeast1"

  # 独自ドメイン配信のため FQDN = バケット名が必須 (Cloudflare CNAME → c.storage.googleapis.com、
  # GCS 側は Host ヘッダでバケットを解決するため名前が一致しないと 404 になる)
  assets_bucket_name    = "overload-party-assets.keyandnotes.com"
  scenarios_bucket_name = "overload-party-prod-scenarios"
  newsfeed_bucket_name  = "overload-party-prod-newsfeed"

  master_data_bucket_name = "overload-party-prod-master-data"

  # prod のみ Cloud Scheduler を有効化。2 時間周期で Cloud Run Job を起動する。
  newsfeed_scheduler_paused = false

  enable_e2e            = false
  e2e_developer_members = []

  gateway_allowed_origins = "capacitor://localhost,http://localhost"

  shop_iap_verifier      = "store"
  shop_apple_environment = "Production"

  alert_email                         = var.alert_email
  alert_slack_notification_channel_id = ""

  billing_account_id = "019A0B-9A103A-B4C602"
  monthly_budget_jpy = 10000
}
