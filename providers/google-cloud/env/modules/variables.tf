variable "project_id" {
  description = "Google Cloud プロジェクト ID"
  type        = string
}

variable "region" {
  description = "Google Cloud リージョン"
  type        = string
}

variable "internal_auth_public_key" {
  description = "gateway が発行する内部認証トークン (RS256) を検証する公開鍵 (PEM)。対になる秘密鍵は Secret Manager に手動投入する"
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

variable "env_name" {
  description = "環境名（dev / stg / prod）"
  type        = string
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

# ──────────────────────────────────────────────
# Cloud Run 移行
# ──────────────────────────────────────────────

variable "gateway_allowed_origins" {
  description = "gateway の CORS 許可オリジン (カンマ区切り)"
  type        = string
}

variable "shop_iap_verifier" {
  description = "shop のレシート検証に実ストア (store) と stub のどちらを使うか"
  type        = string
}

variable "shop_apple_environment" {
  description = "shop の Apple IAP 検証環境 (\"Sandbox\" | \"Production\")。prod のみ Production"
  type        = string
}

variable "support_cors_allowed_origins" {
  description = "support 外部問い合わせフォームの CORS 許可オリジン"
  type        = string
}

variable "support_slack_channel_id" {
  description = "support の問い合わせ通知先 Slack チャンネル ID"
  type        = string
}

variable "support_sendgrid_from_address" {
  description = "support の問い合わせ返信メール送信元アドレス"
  type        = string
}

variable "support_sendgrid_from_name" {
  description = "support の問い合わせ返信メール送信者表示名"
  type        = string
}

# ──────────────────────────────────────────────
# 監視
# ──────────────────────────────────────────────

variable "alert_email" {
  description = "アラートと予算超過の通知先メールアドレス"
  type        = string
  sensitive   = true
}

variable "alert_slack_notification_channel_id" {
  description = "手動作成した Slack 通知チャンネルのリソース名。Slack チャンネルは OAuth 認可を伴うため Terraform では作成できず、Cloud Monitoring のコンソールで作成した名前を受け取る。空文字なら通知先をメールだけにする"
  type        = string
}

variable "billing_account_id" {
  description = "請求先アカウント ID (例: 000000-AAAAAA-BBBBBB)"
  type        = string
}

variable "monthly_budget_jpy" {
  description = "月次予算 (円)。この額の 50 / 75 / 100 % に達した時点で通知する"
  type        = number
}
