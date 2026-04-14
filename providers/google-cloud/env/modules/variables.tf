variable "project_id" {
  description = "Google Cloud プロジェクト ID"
  type        = string
}

variable "region" {
  description = "Google Cloud リージョン"
  type        = string
}

variable "k8s_namespace" {
  description = "Workload Identity バインドに使う Kubernetes namespace"
  type        = string
}

# ──────────────────────────────────────────────
# Cloud SQL
# ──────────────────────────────────────────────

variable "cloudsql_instance_name" {
  description = "Cloud SQL インスタンス名"
  type        = string
}

variable "cloudsql_tier" {
  description = "Cloud SQL マシンタイプ"
  type        = string
}

variable "database_name" {
  description = "PostgreSQL データベース名"
  type        = string
}

variable "deletion_protection" {
  description = "Cloud SQL 削除保護を有効化するか"
  type        = bool
}

variable "ipv4_enabled" {
  description = "Cloud SQL にパブリック IPv4 を割り当てるか"
  type        = bool
}

variable "psc_allowed_consumer_projects" {
  description = "Cloud SQL に PSC 接続を許可する consumer プロジェクト ID 一覧（空なら PSC 無効）"
  type        = list(string)
}

# ──────────────────────────────────────────────
# Firestore
# ──────────────────────────────────────────────

variable "firestore_location" {
  description = "Firestore のロケーション"
  type        = string
}

# ──────────────────────────────────────────────
# GCS バケット名（グローバル一意 - env 側で完全名を構築する）
# ──────────────────────────────────────────────

variable "assets_bucket_name" {
  description = "公開アセットバケット名（CDN CNAME 用、グローバル一意）"
  type        = string
}

variable "scenarios_bucket_name" {
  description = "非公開シナリオスクリプトバケット名（グローバル一意）"
  type        = string
}

variable "newsfeed_bucket_name" {
  description = "Newsfeed 記事データバケット名（グローバル一意）"
  type        = string
}

# ──────────────────────────────────────────────
# Optional 機能（空文字 / false で無効化）
# ──────────────────────────────────────────────

variable "deploy_sa" {
  description = "nightly Cloud SQL 停止用デプロイ SA の IAM member 文字列。空文字なら IAM 付与をスキップ"
  type        = string
}

variable "migration_image" {
  description = "db-migrate コンテナイメージ。空文字なら db_migration モジュール無効"
  type        = string
}

variable "deploy_service_account_email" {
  description = "GitHub Actions デプロイ SA email（Cloud Run Job invoker 付与用）"
  type        = string
}

variable "newsfeed_image" {
  description = "Newsfeed コンテナイメージ"
  type        = string
}
