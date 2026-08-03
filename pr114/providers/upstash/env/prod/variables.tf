variable "upstash_email" {
  description = "Upstash アカウントのメールアドレス"
  type        = string
  sensitive   = true
}

variable "upstash_api_key" {
  description = "Upstash API key (management API 用)"
  type        = string
  sensitive   = true
}
