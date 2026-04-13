variable "project_id" {
  description = "サービス GSA を所有する Google Cloud プロジェクト ID"
  type        = string
}

variable "k8s_services" {
  description = "k8s 内で動くサービス（Workload Identity 対応）。キーは k8s ServiceAccount 名、値は GSA account_id"
  type        = map(string)
}

variable "non_k8s_services" {
  description = "k8s 外で動くサービス（Cloud Run Job 等、WI 不要）。キーは識別子、値は GSA account_id"
  type        = map(string)
}

variable "k8s_namespace" {
  description = "k8s_services の Workload Identity バインドに使う Kubernetes namespace"
  type        = string
}

variable "db_services" {
  description = "Cloud SQL IAM 認証が必要なサービス。キーは k8s_services または non_k8s_services のキーと一致させる"
  type        = map(string)
}

locals {
  gke_project_id = "keyandnotes-platform"
  all_services   = merge(var.k8s_services, var.non_k8s_services)
}
