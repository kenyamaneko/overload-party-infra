variable "project_id" {
  description = "予算の対象にする Google Cloud プロジェクト ID。予算の表示名にも使う"
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
