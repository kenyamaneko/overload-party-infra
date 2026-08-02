variable "project_id" {
  description = "Google Cloud プロジェクト ID"
  type        = string
}

variable "env_name" {
  description = "環境名 (dev / stg / prod)。通知チャンネルと予算の表示名に使う"
  type        = string
}

variable "alert_email" {
  description = "アラートと予算超過の通知先メールアドレス"
  type        = string
  sensitive   = true
}

variable "slack_notification_channel_id" {
  description = "手動作成した Slack 通知チャンネルのリソース名。Slack チャンネルは OAuth 認可を伴うため Terraform では作成できず、Cloud Monitoring のコンソールで作成した名前を受け取る。空文字なら通知先をメールだけにする"
  type        = string
}

variable "billing_account_id" {
  description = "請求先アカウント ID (例: 000000-AAAAAA-BBBBBB)"
  type        = string
}

variable "monthly_budget_jpy" {
  description = "月次予算 (円)。この額の 50 / 80 / 100 % に達した時点で通知する"
  type        = number
}
