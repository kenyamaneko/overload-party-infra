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

  api_records = {
    dev  = { name = "overloadparty-dev" }
    stg  = { name = "overloadparty-stg" }
    prod = { name = "overloadparty-prod" }
  }
}

# ──────────────────────────────────────────────
# DNS -- CNAME レコード (アセット CDN)
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
# DNS -- A レコード (API サーバー)
# ──────────────────────────────────────────────

resource "cloudflare_record" "api" {
  for_each = local.api_records

  zone_id = local.zone_id
  name    = each.value.name
  content = "127.0.0.1"
  type    = "A"
  # Cloudflare は proxied=true に対して 127.0.0.1 のような非 proxiable な IP を拒否する (API error 9003) ため、
  # 初期値は false。env-lifecycle.yaml の up 時に実 IP + proxied=true に書き換えられる。
  proxied = false

  # CI (env-lifecycle.yaml) が Ingress IP / proxied を動的に書き換えるため lifecycle を無視する
  lifecycle {
    ignore_changes = [content, proxied]
  }
}
