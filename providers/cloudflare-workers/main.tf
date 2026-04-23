# Cloudflare Workers Scripts を管理する composition。
# providers/cloudflare/ が DNS (cloudflare_cdn_api_token: DNS Edit) を担当するのに対し、
# Workers Scripts edit 権限の token は別スコープで扱うため composition を分ける。
# Worker のコードデプロイは引き続き wrangler (CI) で行い、Terraform は Worker の枠と
# binding 設定のみ管理する (content は lifecycle.ignore_changes で drift 許容)。

terraform {
  required_version = ">= 1.5"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

variable "cloudflare_workers_api_token" {
  description = "Cloudflare API token (Workers Scripts edit)"
  type        = string
  sensitive   = true
}

locals {
  # Cloudflare account ID は env 横断で固定値。providers/cloudflare/ も同じ account を
  # zone_id 経由で扱っているため、秘匿情報ではなくここでハードコードする。
  cloudflare_account_id = "2fba420f13bcbad7ea84dda8342c08fd"
}

provider "cloudflare" {
  api_token = var.cloudflare_workers_api_token
}

# ──────────────────────────────────────────────
# slack-commands Cloud Run URL は providers/google-cloud/ops composition の output から
# 動的に引く。tfvars へのハードコードをやめ、Cloud Run Service 再作成時の URL 変化に
# 追従できるようにする。
# ──────────────────────────────────────────────

data "terraform_remote_state" "ops" {
  backend = "gcs"

  config = {
    bucket = "keyandnotes-tf-state"
    prefix = "overload-party/ops"
  }
}

# ──────────────────────────────────────────────
# Worker Script: slack-commands-proxy
# ──────────────────────────────────────────────

resource "cloudflare_workers_script" "slack_commands_proxy" {
  account_id = local.cloudflare_account_id
  name       = "slack-commands-proxy"
  module     = true

  # 初回作成用のプレースホルダ。実際のコードは wrangler deploy で管理する。
  content = "export default { async fetch() { return new Response('deployed by wrangler') } }"

  plain_text_binding {
    name = "CLOUD_RUN_URL"
    text = data.terraform_remote_state.ops.outputs.slack_commands_url
  }

  lifecycle {
    ignore_changes = [content]
  }
}
