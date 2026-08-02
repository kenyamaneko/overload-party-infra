variable "project_id" {
  description = "Google Cloud プロジェクト ID"
  type        = string
}

variable "region" {
  description = "GCS バケットのロケーション"
  type        = string
}

variable "bucket_name" {
  description = "カード / 施策マスタを保存する GCS バケット名（グローバル一意）"
  type        = string
}

variable "deploy_sa_member" {
  description = "マスターデータを upload するデプロイ SA の IAM member 文字列"
  type        = string
}

variable "battle_service_account_email" {
  description = "マスターデータを読む battle Cloud Run 実行用 GSA email"
  type        = string
}
