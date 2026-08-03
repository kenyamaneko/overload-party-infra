variable "project_id" {
  description = "Google Cloud プロジェクト ID"
  type        = string
}

variable "region" {
  description = "Google Cloud リージョン"
  type        = string
}

variable "migration_image" {
  description = "マイグレーションジョブのコンテナイメージ"
  type        = string
}

variable "network" {
  description = "Direct VPC Egress 用 VPC ネットワーク名"
  type        = string
}

variable "subnetwork" {
  description = "Direct VPC Egress 用 サブネット名"
  type        = string
}

variable "cloudsql_private_ip" {
  description = "Cloud SQL インスタンスの内部 IP"
  type        = string
}

variable "database_name" {
  description = "接続先 PostgreSQL データベース名"
  type        = string
}

variable "deploy_sa_member" {
  description = "Cloud Run Job invoker / developer / actAs を付与するデプロイ SA の IAM member 文字列"
  type        = string
}
