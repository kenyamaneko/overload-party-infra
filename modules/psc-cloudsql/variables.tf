variable "project_id" {
  description = "Consumer 側プロジェクト ID（GKE が動くプロジェクト）"
  type        = string
}

variable "region" {
  description = "Google Cloud リージョン"
  type        = string
}

variable "network" {
  description = "Consumer 側 VPC ネットワーク名"
  type        = string
}

variable "env_name" {
  description = "環境名（dev / stg / prod）"
  type        = string
}

variable "cloudsql_project_id" {
  description = "Cloud SQL が動くプロジェクト ID"
  type        = string
}

variable "cloudsql_instance_name" {
  description = "Cloud SQL インスタンス名"
  type        = string
}
