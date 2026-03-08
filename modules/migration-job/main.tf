# Cloud Run v2 Job for DB migration with Direct VPC Egress.
# Connects to Cloud SQL via Private IP using password authentication.

# ──────────────────────────────────────────────
# Variables
# ──────────────────────────────────────────────

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "migration_image" {
  description = "Container image for the migration job"
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

variable "db_password_secret_id" {
  description = "Secret Manager secret ID containing the postgres password (created outside Terraform)"
  type        = string
  default     = "migration-db-password"
}

variable "deploy_service_account_email" {
  description = "GitHub Actions deploy SA email (granted roles/run.invoker on this job)"
  type        = string
  default     = ""
}

# ──────────────────────────────────────────────
# Service Account for Cloud Run Job
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
# Cloud Run v2 Job with Direct VPC Egress
# ──────────────────────────────────────────────

resource "google_cloud_run_v2_job" "migration" {
  name                = "db-migrate"
  project             = var.project_id
  location            = var.region
  deletion_protection = false

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
              secret  = var.db_password_secret_id
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
# Allow deploy SA to update and execute the job
# ──────────────────────────────────────────────

resource "google_cloud_run_v2_job_iam_member" "deploy_invoker" {
  count    = var.deploy_service_account_email != "" ? 1 : 0
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_job.migration.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.deploy_service_account_email}"
}

resource "google_cloud_run_v2_job_iam_member" "deploy_developer" {
  count    = var.deploy_service_account_email != "" ? 1 : 0
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_job.migration.name
  role     = "roles/run.developer"
  member   = "serviceAccount:${var.deploy_service_account_email}"
}
