variable "project_id" {
  description = "GCP project ID for the service account"
  type        = string
}

variable "service_account_id" {
  description = "Service account ID"
  type        = string
}

variable "gke_project_id" {
  description = "GCP project ID where GKE cluster lives (for Workload Identity)"
  type        = string
  default     = ""
}

variable "k8s_namespace" {
  description = "Kubernetes namespace for Workload Identity binding"
  type        = string
  default     = "dev"
}

variable "k8s_service_account" {
  description = "Kubernetes ServiceAccount name for Workload Identity binding"
  type        = string
  default     = "game-server"
}

variable "deploy_service_account_email" {
  description = "GitHub Actions deploy SA email (for Cloud SQL start/stop)"
  type        = string
  default     = ""
}

variable "terraform_service_account_email" {
  description = "Terraform deployer SA email (for CI terraform apply)"
  type        = string
  default     = ""
}
