variable "project_id" {
  description = "Google Cloud プロジェクト ID"
  type        = string
}

variable "accessor_service_account_emails" {
  description = "internal-auth-secret への secretAccessor を付与する GSA email のマップ。キーはサービス名"
  type        = map(string)
}
