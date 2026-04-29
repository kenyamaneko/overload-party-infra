# ──────────────────────────────────────────────
# API 有効化
# ──────────────────────────────────────────────

resource "google_project_service" "sqladmin" {
  project            = var.project_id
  service            = "sqladmin.googleapis.com"
  disable_on_destroy = false
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

  # root_password は外部投入。activation_policy は dev/stg の停止/起動を
  # env-lifecycle が所有しており Terraform で enforce するとコスト保護が
  # 失効するため運用状態は外部に委ねる (prod は env-lifecycle 対象外で
  # 手動停止が起きない前提)。
  lifecycle {
    ignore_changes = [
      root_password,
      settings[0].activation_policy,
    ]
  }
}

resource "google_sql_database" "main" {
  name     = var.database_name
  instance = google_sql_database_instance.main.name
  project  = var.project_id
}

resource "google_sql_user" "db_users" {
  for_each = var.db_users

  name     = trimsuffix(each.value, ".gserviceaccount.com")
  instance = google_sql_database_instance.main.name
  project  = var.project_id
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}

resource "google_project_iam_member" "cloudsql_client" {
  for_each = var.db_users

  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${each.value}"
}

resource "google_project_iam_member" "cloudsql_instance_user" {
  for_each = var.db_users

  project = var.project_id
  role    = "roles/cloudsql.instanceUser"
  member  = "serviceAccount:${each.value}"
}
