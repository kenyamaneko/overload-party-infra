variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "asia-northeast1"
}

variable "k8s_namespace" {
  type = string
}

variable "tier" {
  type    = string
  default = "db-g1-small"
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "ipv4_enabled" {
  type    = bool
  default = false
}

variable "psc_allowed_consumer_projects" {
  type    = list(string)
  default = []
}

variable "asset_domain" {
  type = string
}

variable "deploy_sa" {
  description = "IAM member of the deploy SA for nightly Cloud SQL shutdown. Empty = skip."
  type        = string
  default     = ""
}

variable "migration_image" {
  description = "Container image for db-migrate. Empty = skip db_migration module."
  type        = string
  default     = ""
}

variable "deploy_service_account_email" {
  description = "GitHub Actions deploy SA email for Cloud Run job invocation."
  type        = string
  default     = ""
}

variable "enable_newsfeed" {
  type    = bool
  default = false
}

variable "newsfeed_image" {
  type    = string
  default = ""
}
