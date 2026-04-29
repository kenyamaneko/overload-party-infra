# Slack の Slash Command は 3 秒以内に HTTP 200 を返さないと Slack 側でエラー表示になる。
# Cloud Run はコールドスタートでこの制限を超えることがあるため、
# エッジで即座に 200 を返して非同期で Cloud Run に転送する proxy として Workers を挟んでいる。

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

  # slack-commands Cloud Run Service の URL (サービス名 + project + region で固定)。
  # google provider を cloudflare-workers に持ち込まないためハードコードしている。
  slack_commands_url = "https://slack-commands-msfqioc6qa-an.a.run.app"
}

provider "cloudflare" {
  api_token = var.cloudflare_workers_api_token
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
    text = local.slack_commands_url
  }

  lifecycle {
    # content は wrangler (CI) でデプロイするため Terraform の管理対象外
    ignore_changes = [content]
  }
}
