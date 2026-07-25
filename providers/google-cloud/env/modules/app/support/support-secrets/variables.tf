variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "support_service_account_email" {
  description = "Support GSA email to grant secretmanager.secretAccessor"
  type        = string
}
