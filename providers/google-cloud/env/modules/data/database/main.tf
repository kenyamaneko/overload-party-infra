variable "project_id" {
  description = "Google Cloud プロジェクト ID"
  type        = string
}

variable "region" {
  description = "Google Cloud リージョン"
  type        = string
}

variable "instance_name" {
  description = "Cloud SQL インスタンス名"
  type        = string
}

variable "tier" {
  description = "Cloud SQL マシンタイプ"
  type        = string
}

variable "database_name" {
  description = "PostgreSQL データベース名"
  type        = string
}

variable "network_id" {
  description = "Private IP 用 VPC ネットワークの self_link"
  type        = string
}

variable "service_account_id" {
  description = "（DEPRECATED）共有ゲームサーバー GSA。サービス別 IAM 完了後に削除予定"
  type        = string
}

variable "service_iam_users" {
  description = "サービス名 -> GSA email のマップ（サービス別 Cloud SQL IAM ユーザー作成用）"
  type        = map(string)
}

variable "deletion_protection" {
  description = "削除保護を有効化するか"
  type        = bool
}

variable "ipv4_enabled" {
  description = "Cloud SQL インスタンスにパブリック IPv4 を割り当てるか"
  type        = bool
}

variable "psc_allowed_consumer_projects" {
  description = "PSC 接続を許可する consumer プロジェクト ID 一覧（空なら PSC 無効）"
  type        = list(string)
}

# ──────────────────────────────────────────────
# API 有効化
# ──────────────────────────────────────────────

resource "google_project_service" "sqladmin" {
  project            = var.project_id
  service            = "sqladmin.googleapis.com"
  disable_on_destroy = false
}

# ──────────────────────────────────────────────
# サービスアカウント (ゲームサーバー → Cloud SQL)
# ──────────────────────────────────────────────

resource "google_service_account" "game_server" {
  project      = var.project_id
  account_id   = var.service_account_id
  display_name = "Overload Party App"
}

resource "google_project_iam_member" "cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.game_server.email}"
}

resource "google_project_iam_member" "cloudsql_instance_user" {
  project = var.project_id
  role    = "roles/cloudsql.instanceUser"
  member  = "serviceAccount:${google_service_account.game_server.email}"
}

# ──────────────────────────────────────────────
# Cloud SQL インスタンス
# ──────────────────────────────────────────────

resource "google_sql_database_instance" "main" {
  name             = var.instance_name
  project          = var.project_id
  region           = var.region
  database_version = "POSTGRES_16"

  settings {
    tier    = var.tier
    edition = "ENTERPRISE"
    ip_configuration {
      ipv4_enabled    = var.ipv4_enabled
      private_network = var.network_id

      dynamic "psc_config" {
        for_each = length(var.psc_allowed_consumer_projects) > 0 ? [1] : []
        content {
          psc_enabled               = true
          allowed_consumer_projects = var.psc_allowed_consumer_projects
        }
      }
    }
    backup_configuration {
      enabled    = true
      start_time = "03:00"
    }
    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }
  }
  deletion_protection = var.deletion_protection

  # root_password は Terraform 外で初期投入するため ignore。
  # activation_policy は本来 dev/stg のみ「使わない時間帯は落とす」運用で
  # Terraform 外から切り替わるため ignore したいが、Terraform の
  # ignore_changes は静的リテラルしか受け付けず env ごとに変数で切り替える
  # ことができない。prod の手動停止は drift として検知したいので ignore は
  # 載せず全環境一律で plan に差分を出し、dev/stg 分のノイズは drift-monitor
  # 側（targets.yaml の suppress）で抑止する方針にしている。
  lifecycle {
    ignore_changes = [root_password]
  }
}

resource "google_sql_database" "main" {
  name     = var.database_name
  instance = google_sql_database_instance.main.name
  project  = var.project_id
}

resource "google_sql_user" "iam_user" {
  name     = trimsuffix(google_service_account.game_server.email, ".gserviceaccount.com")
  instance = google_sql_database_instance.main.name
  project  = var.project_id
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}

resource "google_sql_user" "service_iam_users" {
  for_each = var.service_iam_users

  name     = trimsuffix(each.value, ".gserviceaccount.com")
  instance = google_sql_database_instance.main.name
  project  = var.project_id
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}

output "private_ip_address" {
  description = "Cloud SQL インスタンスの private IP。newsfeed / db-migration から参照"
  value       = google_sql_database_instance.main.private_ip_address
}
