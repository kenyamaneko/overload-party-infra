variable "project_id" {
  description = "Google Cloud プロジェクト ID"
  type        = string
}

variable "region" {
  description = "Google Cloud リージョン"
  type        = string
}

variable "env_name" {
  description = "環境識別子 (dev / stg / prod)"
  type        = string
}

variable "image" {
  description = "scenario の初期コンテナイメージ (以降の実イメージは CI/CD が所有し ignore_changes 対象)"
  type        = string
}

variable "service_account_email" {
  description = "scenario Cloud Run 実行用 GSA email"
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

variable "story_bucket" {
  description = "ストーリーコンテンツ用 GCS バケット名 (k8s ConfigMap の story-bucket をそのまま踏襲)"
  type        = string
}

variable "player_onboarded_topic" {
  description = "player-onboarded トピック名"
  type        = string
}

variable "onboarding_name_set_topic" {
  description = "onboarding-name-set トピック名"
  type        = string
}

variable "onboarding_faction_set_topic" {
  description = "onboarding-faction-set トピック名"
  type        = string
}

variable "account_base_url" {
  description = "account Cloud Run サービスの URL (オンボーディング名前解決 / 再開判定に使用)"
  type        = string
}
