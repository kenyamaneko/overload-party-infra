variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "shop_service_account_email" {
  description = "Shop GSA email to grant secretmanager.secretAccessor"
  type        = string
}
