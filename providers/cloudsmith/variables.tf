variable "cloudsmith_api_key" {
  description = "Cloudsmith API key。secret.auto.tfvars で供給する (state には sensitive 扱いで保持しない)"
  type        = string
  sensitive   = true
}
