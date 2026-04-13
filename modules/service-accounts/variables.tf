variable "project_id" {
  description = "GCP project ID that owns the service GSAs."
  type        = string
}

variable "services" {
  description = "Map of service name -> GSA account_id. Key = k8s ServiceAccount name, value = GSA account_id."
  type        = map(string)
}

variable "gke_project_id" {
  description = "Project ID that hosts the GKE cluster (used to build the Workload Identity member string)."
  type        = string
  default     = "keyandnotes-platform"
}

variable "k8s_namespace" {
  description = "Kubernetes namespace for Workload Identity binding."
  type        = string
}

variable "db_services" {
  description = "Subset of var.services that need Cloud SQL IAM authentication. Keys must exist in var.services."
  type        = map(string)
  default     = {}
}
