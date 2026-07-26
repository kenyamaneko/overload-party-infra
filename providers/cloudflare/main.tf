terraform {
  required_version = ">= 1.5"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_cdn_api_token
}

locals {
  zone_id = "9b3593693b647e917a656ecf7e49e056" # keyandnotes.com

  assets = {
    dev  = { subdomain = "overload-party-assets-dev" }
    stg  = { subdomain = "overload-party-assets-stg" }
    prod = { subdomain = "overload-party-assets-prod" }
  }

  app_records = {
    "gateway-dev"  = { name = "overloadparty-dev", target = var.app_hostnames["gateway"]["dev"] }
    "gateway-stg"  = { name = "overloadparty-stg", target = var.app_hostnames["gateway"]["stg"] }
    "gateway-prod" = { name = "overloadparty-prod", target = var.app_hostnames["gateway"]["prod"] }
    "news-dev"     = { name = "overloadparty-admin-dev", target = var.app_hostnames["news"]["dev"] }
    "news-stg"     = { name = "overloadparty-admin-stg", target = var.app_hostnames["news"]["stg"] }
    "news-prod"    = { name = "overloadparty-admin-prod", target = var.app_hostnames["news"]["prod"] }
    "support-dev"  = { name = "overloadparty-support-dev", target = var.app_hostnames["support"]["dev"] }
    "support-stg"  = { name = "overloadparty-support-stg", target = var.app_hostnames["support"]["stg"] }
    "support-prod" = { name = "overloadparty-support-prod", target = var.app_hostnames["support"]["prod"] }
  }
}

# ──────────────────────────────────────────────
# GCS は IP を固定していないため A レコードは使えない。CNAME で c.storage.googleapis.com に向ける必要がある。
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
# Cloud Run はホスト名で公開されるため、CNAME で参照する。
# ──────────────────────────────────────────────

resource "cloudflare_record" "app" {
  for_each = local.app_records

  zone_id = local.zone_id
  name    = each.value.name
  content = each.value.target
  type    = "CNAME"
  proxied = true
}

moved {
  from = cloudflare_record.api["dev"]
  to   = cloudflare_record.app["gateway-dev"]
}

moved {
  from = cloudflare_record.api["stg"]
  to   = cloudflare_record.app["gateway-stg"]
}

moved {
  from = cloudflare_record.api["prod"]
  to   = cloudflare_record.app["gateway-prod"]
}
