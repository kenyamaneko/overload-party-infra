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

  env_name   = "dev"
  project_id = "overload-party-dev"
  region     = "asia-northeast1"

  # 対になる秘密鍵は Secret Manager の internal-auth-private-key に手動投入する。
  # 公開鍵は秘密ではないため平文で持つ。
  internal_auth_public_key = <<-EOT
    -----BEGIN PUBLIC KEY-----
    MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAxmcelJAEG0NX5amKXxSp
    B/sP5zbOjKYWhVXH14VOnkPSXEY0AMgXcLu36XT1X0qy85JU4s0tcf6aFOjbWVtD
    y4b3SjiIbM4LI0Mrn1B2yxEKlftLOzHTt0xUKbC+z/rC9gfGmf7lCX68XUJI0Ouu
    xAwYgGpb43TyPPNzqSL57HMfbr7lJXr5JPL5v1flJeWuqO5yO+hhDG2LirFBXVYw
    MDH78YkMEW4U2yKXHCRkeQYJxaKU+mP98s9Mu/RLuz3VlsRu19jgWvXHSCdt75F1
    xb9k2A5gySqdy19VHPY8iK1fVG5i6cnP0diniq/P5B7+kIIvxympg6QMA5L/0kYg
    7wIDAQAB
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
  assets_bucket_name    = "overload-party-assets-dev.keyandnotes.com"
  scenarios_bucket_name = "overload-party-dev-scenarios"
  newsfeed_bucket_name  = "overload-party-dev-newsfeed"

  master_data_bucket_name = "overload-party-dev-master-data"

  # dev は Cloud Scheduler を形式的に配置するのみ (cron は設定するが常時 PAUSED)。
  # 手動実行は `gcloud run jobs execute newsfeed-job` を使う。
  newsfeed_scheduler_paused = true

  enable_e2e            = true
  e2e_developer_members = ["user:kenya.m.amaoto@gmail.com"]

  gateway_allowed_origins = "http://localhost:3000,capacitor://localhost,http://localhost"

  # 本来は Sandbox の実ストアを叩く設計だが、App Store Connect API キーが未発行で
  # shop が起動できないため暫定的に stub にしている。復帰は overload-party-shop#129。
  shop_iap_verifier      = "stub"
  shop_apple_environment = "Sandbox"

  alert_email                         = var.alert_email
  alert_slack_notification_channel_id = ""

  billing_account_id = "019A0B-9A103A-B4C602"
  monthly_budget_jpy = 1000
}

