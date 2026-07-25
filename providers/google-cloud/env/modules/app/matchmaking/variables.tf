variable "project_id" {
  description = "Google Cloud プロジェクト ID"
  type        = string
}

variable "region" {
  description = "Google Cloud リージョン"
  type        = string
}

variable "image" {
  description = "matchmaking の初期コンテナイメージ (以降の実イメージは CI/CD が所有し ignore_changes 対象)"
  type        = string
}

variable "service_account_email" {
  description = "matchmaking Cloud Run 実行用 GSA email"
  type        = string
}

variable "max_instance_count" {
  description = "Cloud Run 最大インスタンス数"
  type        = number
}

variable "resources_limit_cpu" {
  description = "コンテナ CPU 上限 (k8s limits.cpu 相当)"
  type        = string
}

variable "resources_limit_memory" {
  description = "コンテナメモリ上限 (k8s limits.memory 相当)"
  type        = string
}

variable "internal_auth_secret_id" {
  description = "内部認証共有鍵 (HS256) の Secret Manager secret_id"
  type        = string
}

variable "match_made_topic" {
  description = "matchmaking-events トピック名"
  type        = string
}
