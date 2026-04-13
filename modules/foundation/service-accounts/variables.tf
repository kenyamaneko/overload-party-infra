variable "project_id" {
  description = "サービス GSA を所有する Google Cloud プロジェクト ID"
  type        = string
}

variable "services" {
  description = "サービス名 -> GSA account_id のマップ。キーは k8s ServiceAccount 名、値は GSA account_id"
  type        = map(string)
}

variable "k8s_namespace" {
  description = "Workload Identity バインドに使う Kubernetes namespace"
  type        = string
}

variable "db_services" {
  description = "Cloud SQL IAM 認証が必要なサービス。キーは var.services のキーと一致させる"
  type        = map(string)
}

locals {
  gke_project_id = "keyandnotes-platform"
}
