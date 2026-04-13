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

variable "deploy_sa" {
  description = "nightly-shutdown 用に Cloud SQL 操作権限（roles/cloudsql.editor）を付与する IAM member 文字列。空文字なら付与スキップ"
  type        = string
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

  # root_password と activation_policy は Terraform 外で管理
  lifecycle {
    ignore_changes = [root_password, settings[0].activation_policy]
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

resource "google_project_iam_member" "deploy_cloudsql_editor" {
  count   = var.deploy_sa != "" ? 1 : 0
  project = var.project_id
  role    = "roles/cloudsql.editor"
  member  = var.deploy_sa
}

# ──────────────────────────────────────────────
# 出力
# ──────────────────────────────────────────────

output "instance_connection_name" {
  value = google_sql_database_instance.main.connection_name
}

output "instance_name" {
  description = "Cloud SQL instance short name"
  value       = google_sql_database_instance.main.name
}

output "database_url_iam" {
  value = "host=localhost port=5432 dbname=${var.database_name} user=${google_sql_user.iam_user.name} sslmode=disable"
}

output "service_database_urls" {
  description = "Map of service name -> DSN using per-service IAM user"
  value = {
    for svc, user in google_sql_user.service_iam_users :
    svc => "host=localhost port=5432 dbname=${var.database_name} user=${user.name} sslmode=disable"
  }
}

output "private_ip_address" {
  description = "Private IP address of the Cloud SQL instance"
  value       = google_sql_database_instance.main.private_ip_address
}

output "psc_service_attachment_link" {
  description = "PSC service attachment link (empty if PSC disabled)"
  value       = length(var.psc_allowed_consumer_projects) > 0 ? google_sql_database_instance.main.psc_service_attachment_link : ""
}

output "dns_name" {
  description = "PSC DNS name (empty if PSC disabled)"
  value       = length(var.psc_allowed_consumer_projects) > 0 ? google_sql_database_instance.main.dns_name : ""
}

output "service_account_email" {
  value = google_service_account.game_server.email
}
