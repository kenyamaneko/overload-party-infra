# ──────────────────────────────────────────────
# 変数
# ──────────────────────────────────────────────

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "newsfeed_image" {
  description = "Container image for the newsfeed job"
  type        = string
}

variable "network" {
  description = "VPC network name for Direct VPC Egress"
  type        = string
}

variable "subnetwork" {
  description = "VPC subnetwork name for Direct VPC Egress"
  type        = string
}

variable "cloudsql_private_ip" {
  description = "Private IP address of the Cloud SQL instance"
  type        = string
}

variable "database_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "overload_party"
}

variable "vertex_location" {
  description = "Vertex AI region"
  type        = string
  default     = "us-central1"
}

variable "schedule" {
  description = "Cron schedule for the newsfeed job"
  type        = string
  default     = "0 */2 * * *" # every 2 hours
}

variable "timezone" {
  description = "Timezone for Cloud Scheduler"
  type        = string
  default     = "Asia/Tokyo"
}

variable "deploy_service_account_email" {
  description = "GitHub Actions deploy SA email (granted roles/run.invoker on this job)"
  type        = string
  default     = ""
}

variable "service_account_email" {
  description = "GSA email for the newsfeed Cloud Run Job"
  type        = string
}

# ──────────────────────────────────────────────
# API 有効化
# ──────────────────────────────────────────────

resource "google_project_service" "run" {
  project            = var.project_id
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloudscheduler" {
  project            = var.project_id
  service            = "cloudscheduler.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "aiplatform" {
  project            = var.project_id
  service            = "aiplatform.googleapis.com"
  disable_on_destroy = false
}

# ──────────────────────────────────────────────
# GCS バケット (記事データ保存)
# ──────────────────────────────────────────────

resource "google_storage_bucket" "newsfeed" {
  name                        = "${var.project_id}-newsfeed"
  project                     = var.project_id
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = false

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }
}

# ──────────────────────────────────────────────
# IAM (Cloud SQL は module.service_accounts で付与)
# ──────────────────────────────────────────────

resource "google_storage_bucket_iam_member" "newsfeed_gcs_writer" {
  bucket = google_storage_bucket.newsfeed.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${var.service_account_email}"
}

resource "google_storage_bucket_iam_member" "newsfeed_gcs_reader" {
  bucket = google_storage_bucket.newsfeed.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${var.service_account_email}"
}

resource "google_project_iam_member" "newsfeed_vertex_ai_user" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${var.service_account_email}"
}

# ──────────────────────────────────────────────
# Cloud Run v2 ジョブ
# ──────────────────────────────────────────────

resource "google_cloud_run_v2_job" "newsfeed" {
  name                = "newsfeed-job"
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
      service_account = var.service_account_email
      max_retries     = 1
      timeout         = "1800s" # 30 min max

      containers {
        image = var.newsfeed_image

        env {
          name  = "DATABASE_URL"
          value = "postgres://${var.service_account_email}@${var.cloudsql_private_ip}:5432/${var.database_name}?sslmode=disable"
        }

        env {
          name  = "GCS_BUCKET"
          value = google_storage_bucket.newsfeed.name
        }

        env {
          name  = "GCP_PROJECT"
          value = var.project_id
        }

        env {
          name  = "VERTEX_LOCATION"
          value = var.vertex_location
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
# Cloud Scheduler (Newsfeed ジョブトリガー)
# ──────────────────────────────────────────────

resource "google_service_account" "newsfeed_scheduler" {
  project      = var.project_id
  account_id   = "newsfeed-scheduler"
  display_name = "Newsfeed Cloud Scheduler"
}

resource "google_cloud_run_v2_job_iam_member" "scheduler_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_job.newsfeed.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.newsfeed_scheduler.email}"
}

resource "google_cloud_scheduler_job" "newsfeed" {
  name        = "newsfeed-fetch"
  project     = var.project_id
  region      = var.region
  description = "Trigger newsfeed Cloud Run Job every 2 hours"
  schedule    = var.schedule
  time_zone   = var.timezone

  http_target {
    http_method = "POST"
    uri         = "https://${var.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${var.project_id}/jobs/${google_cloud_run_v2_job.newsfeed.name}:run"

    oauth_token {
      service_account_email = google_service_account.newsfeed_scheduler.email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }
}

# ──────────────────────────────────────────────
# デプロイ SA にジョブ実行権限を付与 (CI/CD)
# ──────────────────────────────────────────────

resource "google_cloud_run_v2_job_iam_member" "deploy_invoker" {
  count    = var.deploy_service_account_email != "" ? 1 : 0
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_job.newsfeed.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.deploy_service_account_email}"
}

# ──────────────────────────────────────────────
# 出力
# ──────────────────────────────────────────────

output "newsfeed_job_name" {
  value = google_cloud_run_v2_job.newsfeed.name
}

output "gcs_bucket_name" {
  value = google_storage_bucket.newsfeed.name
}

