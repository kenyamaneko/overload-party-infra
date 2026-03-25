variable "project_id" {
  description = "GCP project ID (keyandnotes-platform)"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "asia-northeast1"
}

variable "github_owner" {
  description = "GitHub organization or user name"
  type        = string
}

variable "allowed_repositories" {
  description = "All repositories allowed to authenticate via WIF"
  type        = list(string)
}

variable "ci_wif_repositories" {
  description = "Repositories allowed to authenticate as the CI service account"
  type        = list(string)
}

variable "terraform_wif_repositories" {
  description = "Repositories allowed to authenticate as the Terraform deployer service account"
  type        = list(string)
}

variable "artifact_registry_id" {
  description = "Artifact Registry repository ID for CI writer access"
  type        = string
}

variable "cloudfunctions_projects" {
  description = "GCP projects where CI SA needs Cloud Functions deploy permission"
  type        = list(string)
  default     = []
}

variable "cloudrun_projects" {
  description = "GCP projects where CI SA needs Cloud Run Jobs update permission"
  type        = list(string)
  default     = []
}

variable "terraform_editor_projects" {
  description = "GCP projects where Terraform deployer SA needs editor permission"
  type        = list(string)
}

variable "cloudsql_admin_projects" {
  description = "GCP projects where CI SA needs Cloud SQL admin permission (start/stop)"
  type        = list(string)
  default     = []
}
