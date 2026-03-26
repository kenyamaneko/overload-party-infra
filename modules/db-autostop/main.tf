# Cloud Scheduler: auto-stop/start Cloud SQL to minimize costs.
# Calls the Cloud SQL Admin API directly via HTTP target with OAuth.

variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "cloudsql_instance" {
  type    = string
  default = "overload-party-db"
}

variable "stop_schedule" {
  type        = string
  description = "Cron schedule for stopping Cloud SQL (in the configured timezone)"
  default     = "0 2 * * *" # 2:00 AM
}

variable "start_schedule" {
  type        = string
  description = "Cron schedule for starting Cloud SQL (empty = no auto-start)"
  default     = ""
}

variable "timezone" {
  type    = string
  default = "Asia/Tokyo"
}

# ──────────────────────────────────────────────
# APIs
# ──────────────────────────────────────────────

resource "google_project_service" "cloudscheduler" {
  project            = var.project_id
  service            = "cloudscheduler.googleapis.com"
  disable_on_destroy = false
}

# ──────────────────────────────────────────────
# Service Account for Cloud Scheduler
# ──────────────────────────────────────────────

resource "google_service_account" "scheduler" {
  account_id   = "cloudsql-scheduler"
  display_name = "Cloud SQL Scheduler"
  project      = var.project_id
}

resource "google_project_iam_member" "scheduler_cloudsql_admin" {
  project = var.project_id
  role    = "roles/cloudsql.admin"
  member  = "serviceAccount:${google_service_account.scheduler.email}"
}

# ──────────────────────────────────────────────
# Cloud Scheduler: Stop Cloud SQL
# ──────────────────────────────────────────────

resource "google_cloud_scheduler_job" "stop_cloudsql" {
  name        = "stop-cloudsql"
  project     = var.project_id
  region      = var.region
  description = "Stop Cloud SQL instance to reduce costs"
  schedule    = var.stop_schedule
  time_zone   = var.timezone

  http_target {
    http_method = "PATCH"
    uri         = "https://sqladmin.googleapis.com/v1/projects/${var.project_id}/instances/${var.cloudsql_instance}"
    body = base64encode(jsonencode({
      settings = {
        activationPolicy = "NEVER"
      }
    }))
    headers = {
      "Content-Type" = "application/json"
    }

    oauth_token {
      service_account_email = google_service_account.scheduler.email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }
}

# ──────────────────────────────────────────────
# Cloud Scheduler: Start Cloud SQL (optional)
# ──────────────────────────────────────────────

resource "google_cloud_scheduler_job" "start_cloudsql" {
  count = var.start_schedule != "" ? 1 : 0

  name        = "start-cloudsql"
  project     = var.project_id
  region      = var.region
  description = "Start Cloud SQL instance"
  schedule    = var.start_schedule
  time_zone   = var.timezone

  http_target {
    http_method = "PATCH"
    uri         = "https://sqladmin.googleapis.com/v1/projects/${var.project_id}/instances/${var.cloudsql_instance}"
    body = base64encode(jsonencode({
      settings = {
        activationPolicy = "ALWAYS"
      }
    }))
    headers = {
      "Content-Type" = "application/json"
    }

    oauth_token {
      service_account_email = google_service_account.scheduler.email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }
}
