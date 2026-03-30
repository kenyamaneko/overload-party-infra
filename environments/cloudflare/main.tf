# Cloudflare CDN for game assets.
#
# GCS の CNAME バケット機能を利用する。バケット名 = サブドメインにすることで、
# Cloudflare がプロキシしたリクエストの Host ヘッダから GCS が自動的にバケットを解決する。
# Origin Rule や Transform Rule は不要。
#
# 前提: Cloudflare の SSL モードが Flexible であること
# （GCS CNAME バケットは HTTP のみ対応のため）。

terraform {
  required_version = ">= 1.5"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

variable "cloudflare_cdn_api_token" {
  description = "Cloudflare API token (DNS Edit)"
  type        = string
  sensitive   = true
}

provider "cloudflare" {
  api_token = var.cloudflare_cdn_api_token
}

# ──────────────────────────────────────────────
# Locals
# ──────────────────────────────────────────────

locals {
  zone_id = "9b3593693b647e917a656ecf7e49e056"

  assets = {
    dev  = { subdomain = "overload-party-assets-dev" }
    stg  = { subdomain = "overload-party-assets-stg" }
    prod = { subdomain = "overload-party-assets" }
  }
}

resource "cloudflare_record" "assets" {
  for_each = local.assets

  zone_id = local.zone_id
  name    = each.value.subdomain
  content = "c.storage.googleapis.com"
  type    = "CNAME"
  proxied = true
}
