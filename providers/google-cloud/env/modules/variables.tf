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
# コンテナイメージ
# ──────────────────────────────────────────────


variable "newsfeed_scheduler_paused" {
  description = "Newsfeed の Cloud Scheduler を PAUSED 状態で作成するか。prod=false、dev/stg=true (手動 resume でリリース前検証)"
  type        = bool
}

# ──────────────────────────────────────────────
# E2E テスト
# ──────────────────────────────────────────────

variable "enable_e2e" {
  description = "E2E テスト用の SA / Secret Manager 枠を作成するか (dev/stg のみ true)"
  type        = bool
}

variable "e2e_developer_members" {
  description = "E2E secret への secretAccessor を付与する開発者 IAM member (例: user:foo@example.com)"
  type        = list(string)
}
