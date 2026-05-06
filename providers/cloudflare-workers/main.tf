terraform {
  required_version = ">= 1.5"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

locals {
  # Cloudflare account ID は env 横断で固定値。providers/cloudflare/ も同じ account を
  # zone_id 経由で扱っているため、秘匿情報ではなくここでハードコードする。
  cloudflare_account_id = "2fba420f13bcbad7ea84dda8342c08fd"
}

provider "cloudflare" {
  api_token = var.cloudflare_workers_api_token
}
