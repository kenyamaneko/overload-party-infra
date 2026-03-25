variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "tier" {
  description = "Cloud SQL machine tier"
  type        = string
  default     = "db-g1-small"
}

variable "database_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "overload_party"
}

variable "network_id" {
  description = "VPC network self_link for private IP"
  type        = string
}

variable "service_account_email" {
  description = "GSA email for IAM database authentication"
  type        = string
  default     = ""
}

variable "deletion_protection" {
  description = "Whether deletion protection is enabled"
  type        = bool
  default     = false
}

variable "ipv4_enabled" {
  description = "Whether to assign a public IPv4 address to the Cloud SQL instance"
  type        = bool
  default     = false
}

variable "psc_allowed_consumer_projects" {
  description = "Project IDs allowed to connect via PSC (empty = PSC disabled)"
  type        = list(string)
  default     = []
}

resource "google_sql_database_instance" "main" {
  name             = "overload-party-db"
  project          = var.project_id
  region           = var.region
  database_version = "POSTGRES_16"

  settings {
    tier    = var.tier
    edition = "ENTERPRISE"
    ip_configuration {
      ipv4_enabled    = var.ipv4_enabled
      # private_network (VPC peering) と PSC は併用可能。
      # private_network: 同一プロジェクト内の Cloud Run Job が private IP で接続
      # PSC: 別プロジェクト (keyandnotes-platform) の GKE から接続
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

  # root_password は初回作成後に外部で管理されるため、Terraform の差分検知から除外
  lifecycle {
    ignore_changes = [root_password]
  }
}

resource "google_sql_database" "main" {
  name     = var.database_name
  instance = google_sql_database_instance.main.name
  project  = var.project_id
}

# IAM database user (for Cloud SQL Auth Proxy with --auto-iam-authn)
resource "google_sql_user" "iam_user" {
  count    = var.service_account_email != "" ? 1 : 0
  name     = trimsuffix(var.service_account_email, ".gserviceaccount.com")
  instance = google_sql_database_instance.main.name
  project  = var.project_id
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}

output "instance_connection_name" {
  value = google_sql_database_instance.main.connection_name
}

# IAM auth: DSN format for Auth Proxy sidecar (app connects to localhost:5432)
output "database_url_iam" {
  value = var.service_account_email != "" ? "host=localhost port=5432 dbname=${var.database_name} user=${google_sql_user.iam_user[0].name} sslmode=disable" : ""
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
