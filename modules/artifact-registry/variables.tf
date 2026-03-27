variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "asia-northeast1"
}

variable "repository_id" {
  description = "Artifact Registry repository ID"
  type        = string
  default     = "overload-party"
}
