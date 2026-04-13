variable "project_id" {
  description = "Consumer project ID (where GKE runs)"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "network" {
  description = "Consumer VPC network name"
  type        = string
}

variable "env_name" {
  description = "Environment name (dev, stg, prod)"
  type        = string
}

variable "cloudsql_project_id" {
  description = "Project ID where Cloud SQL runs"
  type        = string
}

variable "cloudsql_instance_name" {
  description = "Cloud SQL instance name"
  type        = string
  default     = "overload-party-db"
}
