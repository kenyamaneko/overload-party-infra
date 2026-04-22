locals {
  db_password_secret_id = "migration-db-password"
}

# ──────────────────────────────────────────────
# API 有効化
# ──────────────────────────────────────────────

resource "google_project_service" "run" {
  project            = var.project_id
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

# ──────────────────────────────────────────────
# DB migration 用 Secret Manager シークレット
# Terraform が作るのは 枠 のみ。バージョン (実値) は手動で追加する:
#   gcloud secrets versions add migration-db-password --project <project_id> --data-file=- <<< "<password>"
# ──────────────────────────────────────────────

resource "google_secret_manager_secret" "db_password" {
  project   = var.project_id
  secret_id = local.db_password_secret_id

  replication {
    auto {}
  }
}

# ──────────────────────────────────────────────
# Cloud Run Job 用サービスアカウント
# ──────────────────────────────────────────────

resource "google_service_account" "migration" {
  project      = var.project_id
  account_id   = "db-migrator"
  display_name = "DB Migration (Cloud Run Job)"
}

resource "google_project_iam_member" "migration_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.migration.email}"
}

# ──────────────────────────────────────────────
# Cloud Run v2 ジョブ (Direct VPC Egress)
# ──────────────────────────────────────────────

resource "google_cloud_run_v2_job" "migration" {
  name                = "db-migrate"
  project             = var.project_id
  location            = var.region
  deletion_protection = false

  # CI/CD がイメージタグを直接更新するため drift を許容
  lifecycle {
    ignore_changes = [template[0].template[0].containers[0].image]
  }

  template {
    task_count = 1

    template {
      service_account = google_service_account.migration.email
      max_retries     = 0
      timeout         = "300s"

      containers {
        image = var.migration_image

        env {
          name  = "DATABASE_HOST"
          value = var.cloudsql_private_ip
        }

        env {
          name  = "DATABASE_PORT"
          value = "5432"
        }

        env {
          name  = "DATABASE_NAME"
          value = var.database_name
        }

        env {
          name  = "DATABASE_USER"
          value = "postgres"
        }

        env {
          name = "DATABASE_PASSWORD"
          value_source {
            secret_key_ref {
              secret  = local.db_password_secret_id
              version = "latest"
            }
          }
        }
      }

      vpc_access {
        network_interfaces {
          network    = var.network
          subnetwork = var.subnetwork
        }
        egress = "PRIVATE_RANGES_ONLY"
      }
    }
  }

}

# ──────────────────────────────────────────────
# デプロイ SA にジョブ更新・実行権限を付与
# ──────────────────────────────────────────────

resource "google_cloud_run_v2_job_iam_member" "deploy_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_job.migration.name
  role     = "roles/run.invoker"
  member   = var.deploy_sa_member
}

resource "google_cloud_run_v2_job_iam_member" "deploy_developer" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_job.migration.name
  role     = "roles/run.developer"
  member   = var.deploy_sa_member
}

resource "google_service_account_iam_member" "deploy_act_as_migration" {
  service_account_id = google_service_account.migration.name
  role               = "roles/iam.serviceAccountUser"
  member             = var.deploy_sa_member
}

moved {
  from = google_cloud_run_v2_job_iam_member.deploy_invoker[0]
  to   = google_cloud_run_v2_job_iam_member.deploy_invoker
}

moved {
  from = google_cloud_run_v2_job_iam_member.deploy_developer[0]
  to   = google_cloud_run_v2_job_iam_member.deploy_developer
}

moved {
  from = google_service_account_iam_member.deploy_act_as_migration[0]
  to   = google_service_account_iam_member.deploy_act_as_migration
}
