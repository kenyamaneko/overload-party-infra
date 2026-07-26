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
  description = "gateway の初期コンテナイメージ (以降の実イメージは CI/CD が revision を作成して切り替える)"
  type        = string
}

variable "container_port" {
  description = "gateway コンテナが listen する HTTP ポート"
  type        = number
}

variable "max_concurrent_connections" {
  description = "1 インスタンスが同時に受ける WebSocket 接続数の上限"
  type        = number
}

variable "request_timeout_sec" {
  description = "リクエストの最大実行時間 (秒)。WebSocket 接続はこの時間で切れる"
  type        = number
}

variable "resources_limit_cpu" {
  description = "コンテナの CPU 上限 (Cloud Run の cpu 表記)"
  type        = string
}

variable "resources_limit_memory" {
  description = "コンテナのメモリ上限 (Cloud Run の memory 表記)"
  type        = string
}

variable "service_account_email" {
  description = "gateway の runtime GSA email"
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
  description = "Cloud SQL インスタンスの接続名 (project:region:instance)"
  type        = string
}

variable "database_name" {
  description = "接続先 PostgreSQL データベース名"
  type        = string
}

variable "internal_auth_secret_id" {
  description = "内部認証トークンの署名鍵を保持する Secret Manager シークレット ID"
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

variable "matchmaking_timeout_sec" {
  description = "マッチング待機タイムアウト (秒)"
  type        = number
}

variable "pubsub_push_service_account_email" {
  description = "push 購読の OIDC トークン署名に使うサービスアカウントのメールアドレス。push 受け口の検証に使う"
  type        = string
}

variable "pubsub_push_audience" {
  description = "push 購読の OIDC トークンの audience。push 受け口の検証に使う"
  type        = string
}
