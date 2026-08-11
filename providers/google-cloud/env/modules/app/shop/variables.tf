variable "project_id" {
  description = "Google Cloud プロジェクト ID"
  type        = string
}

variable "region" {
  description = "Google Cloud リージョン"
  type        = string
}

variable "image" {
  description = "shop の初期コンテナイメージ (以降の実イメージは CI/CD が所有し ignore_changes 対象)"
  type        = string
}

variable "service_account_email" {
  description = "shop Cloud Run 実行用 GSA email"
  type        = string
}

variable "network" {
  description = "Direct VPC Egress 用 VPC ネットワーク名"
  type        = string
}

variable "subnetwork" {
  description = "Direct VPC Egress 用サブネット名"
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

variable "db_pool_max_conns" {
  description = "1 インスタンスが張る接続プールの上限"
  type        = number
}

variable "max_instance_count" {
  description = "Cloud Run 最大インスタンス数 (Cloud SQL コネクション枯渇防止の上限)"
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

variable "internal_auth_public_key" {
  description = "内部認証トークン (RS256) を検証する gateway の公開鍵 (PEM)。公開鍵は秘密ではないため平文で渡す"
  type        = string
}

variable "faction_acquired_topic" {
  description = "faction-acquired トピック名"
  type        = string
}

variable "card_pack_purchased_topic" {
  description = "card-pack-purchased トピック名"
  type        = string
}

variable "premium_updated_topic" {
  description = "premium-updated トピック名"
  type        = string
}

variable "iap_verifier" {
  description = "レシート検証に実ストア (store) と stub のどちらを使うか。叩くストア環境は apple_environment が別に決める"
  type        = string
}

variable "apple_environment" {
  description = "Apple IAP 検証環境 (\"Sandbox\" | \"Production\")。prod のみ Production"
  type        = string
}

variable "pubsub_push_service_account_email" {
  description = "push 購読の OIDC トークン署名に使うサービスアカウントのメールアドレス。push 受け口の検証に使う"
  type        = string
}

variable "pubsub_push_audience" {
  description = "push 購読の OIDC トークンの audience。push 受け口の検証に使う"
  type        = string
}
