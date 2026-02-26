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

resource "google_sql_database_instance" "main" {
  name             = "overload-party-db"
  project          = var.project_id
  region           = var.region
  database_version = "POSTGRES_16"

  settings {
    tier    = var.tier
    edition = "ENTERPRISE"
    ip_configuration {
      ipv4_enabled    = true  # Auth Proxy (CI db-migrate) uses public IP with IAM auth
      private_network = var.network_id
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
