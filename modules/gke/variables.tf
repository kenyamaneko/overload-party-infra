variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "asia-northeast1"
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "keyandnotes-shared"
}

variable "network" {
  description = "VPC network name"
  type        = string
  default     = "default"
}
