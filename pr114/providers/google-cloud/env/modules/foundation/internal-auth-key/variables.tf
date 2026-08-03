variable "project_id" {
  description = "Google Cloud プロジェクト ID"
  type        = string
}

variable "signer_service_account_email" {
  description = "内部トークンに署名する gateway の GSA email。秘密鍵を読める唯一の主体"
  type        = string
}
