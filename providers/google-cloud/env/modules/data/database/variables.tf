variable "project_id" {
  description = "Google Cloud プロジェクト ID"
  type        = string
}

variable "region" {
  description = "Google Cloud リージョン"
  type        = string
}

variable "instance_name" {
  description = "Cloud SQL インスタンス名"
  type        = string
}

variable "tier" {
  description = "Cloud SQL マシンタイプ"
  type        = string
}

variable "database_name" {
  description = "PostgreSQL データベース名"
  type        = string
}

variable "network_id" {
  description = "Private IP 用 VPC ネットワークの self_link"
  type        = string
}

variable "db_users" {
  description = "サービス別 Cloud SQL IAM ユーザを作成するためのマップ。キーはサービス名、値はそのサービスの GSA email"
  type        = map(string)
}

variable "deletion_protection" {
  description = "削除保護を有効化するか"
  type        = bool
}

variable "ipv4_enabled" {
  description = "Cloud SQL インスタンスにパブリック IPv4 を割り当てるか"
  type        = bool
}

variable "psc_allowed_consumer_projects" {
  description = "PSC 接続を許可する consumer プロジェクト ID 一覧（空なら PSC 無効）"
  type        = list(string)
}
