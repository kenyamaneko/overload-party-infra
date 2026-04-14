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
# ローカル変数
# ──────────────────────────────────────────────

locals {
  zone_id = "9b3593693b647e917a656ecf7e49e056" # keyandnotes.com

  assets = {
    dev  = { subdomain = "overload-party-assets-dev" }
    stg  = { subdomain = "overload-party-assets-stg" }
    prod = { subdomain = "overload-party-assets" }
  }

  # API サーバー DNS レコード (k8s リポから移管)
  api_records = {
    dev  = { name = "overloadparty-dev" }
    prod = { name = "overloadparty-prod" }
  }
}

# ──────────────────────────────────────────────
# DNS -- CNAME レコード (アセット CDN)
# ──────────────────────────────────────────────

resource "cloudflare_record" "assets" {
  for_each = local.assets

  zone_id = local.zone_id
  name    = each.value.subdomain
  content = "c.storage.googleapis.com"
  type    = "CNAME"
  proxied = true
}

# ──────────────────────────────────────────────
# DNS -- A レコード (API サーバー、k8s リポから移管)
# ──────────────────────────────────────────────

resource "cloudflare_record" "api" {
  for_each = local.api_records

  zone_id = local.zone_id
  name    = each.value.name
  content = "127.0.0.1"
  type    = "A"
  proxied = true

  # CI (env-lifecycle.yaml) が Ingress IP で動的に書き換える
  lifecycle {
    ignore_changes = [content, proxied]
  }
}
