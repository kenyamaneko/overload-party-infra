variable "cloudflare_cdn_api_token" {
  description = "Cloudflare API token (DNS Edit)"
  type        = string
  sensitive   = true
}

variable "app_hostnames" {
  description = "Cloud Run サービスのホスト名。外側キーはサービス識別子、内側キーは環境 (dev/stg/prod)"
  type        = map(map(string))
}
