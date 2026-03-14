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
