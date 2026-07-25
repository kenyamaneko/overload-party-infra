variable "project_id" {
  description = "Google Cloud プロジェクト ID"
  type        = string
}

variable "region" {
  description = "Google Cloud リージョン"
  type        = string
}

variable "env_name" {
  description = "環境識別子 (dev / stg / prod)。gateway の ENV 環境変数にそのまま渡す"
  type        = string
}

variable "image" {
  description = "gateway の初期コンテナイメージ (以降の実イメージは CI/CD が新しい instance template を作成して切り替える)"
  type        = string
}

variable "machine_type" {
  description = "GCE マシンタイプ"
  type        = string
}

variable "use_static_ip" {
  description = "外部静的 IP を予約するか (prod=true、dev/stg=false で ephemeral IP)"
  type        = bool
}

variable "container_port" {
  description = "gateway コンテナが listen する HTTP ポート"
  type        = number
}

variable "service_account_email" {
  description = "gateway VM 実行用 GSA email"
  type        = string
}

variable "network" {
  description = "VPC ネットワーク名"
  type        = string
}

variable "subnetwork" {
  description = "サブネット名"
  type        = string
}

variable "cloudsql_connection_name" {
  description = "Cloud SQL インスタンスの接続名 (project:region:instance)。cloud-sql-proxy サイドカーに渡す"
  type        = string
}

variable "database_name" {
  description = "接続先 PostgreSQL データベース名"
  type        = string
}

variable "allowed_origins" {
  description = "CORS 許可オリジン (カンマ区切り)"
  type        = string
}

variable "battle_service_url" {
  description = "battle Cloud Run サービスの URL"
  type        = string
}

variable "card_service_url" {
  description = "card Cloud Run サービスの URL"
  type        = string
}

variable "matchmaking_service_url" {
  description = "matchmaking Cloud Run サービスの URL"
  type        = string
}

variable "account_service_url" {
  description = "account Cloud Run サービスの URL"
  type        = string
}

variable "shop_service_url" {
  description = "shop Cloud Run サービスの URL"
  type        = string
}

variable "scenario_service_url" {
  description = "scenario Cloud Run サービスの URL"
  type        = string
}

variable "news_service_url" {
  description = "news Cloud Run サービスの URL"
  type        = string
}

variable "support_service_url" {
  description = "support Cloud Run サービスの URL"
  type        = string
}

variable "matchmaking_subscription" {
  description = "matchmaking-events の gateway 向け pull subscription 名"
  type        = string
}

variable "matchmaking_timeout_sec" {
  description = "マッチング待機タイムアウト (秒)"
  type        = number
}

variable "artifact_registry_project_id" {
  description = "中央 Artifact Registry を保持するプロジェクト ID (keyandnotes-platform)"
  type        = string
}

variable "artifact_registry_location" {
  description = "中央 Artifact Registry のロケーション"
  type        = string
}

variable "artifact_registry_repository_id" {
  description = "中央 Artifact Registry のリポジトリ ID"
  type        = string
}
