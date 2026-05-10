terraform {
  required_version = ">= 1.5"

  required_providers {
    cloudsmith = {
      source  = "cloudsmith-io/cloudsmith"
      version = "~> 0.0"
    }
  }
}

provider "cloudsmith" {
  api_key = var.cloudsmith_api_key
}

locals {
  organization = "keyandnotes"
  github_owner = "kenyamaneko"

  repositories = {
    nuget = "overload-party-nuget"
    npm   = "overload-party-npm"
  }

  publisher_repos = [
    "overload-party-common",
    "overload-party-battle",
    "overload-party-card",
    "overload-party-shop",
  ]

  # ops/modules/ci-cd の ci_wif_repositories と同じ集合を使う
  reader_repos = [
    "overload-party-account",
    "overload-party-analytics",
    "overload-party-assets",
    "overload-party-battle",
    "overload-party-card",
    "overload-party-client",
    "overload-party-common",
    "overload-party-gateway",
    "overload-party-infra",
    "overload-party-matchmaking",
    "overload-party-newsfeed",
    "overload-party-ops",
    "overload-party-scenario",
    "overload-party-shop",
  ]
}

data "cloudsmith_organization" "this" {
  slug = local.organization
}

# API key 所有者を repository_privileges に Admin で含めないと apply が拒否される (lockout 防止)
data "cloudsmith_user_self" "current" {}

# Cloudsmith は multi-format で 1 repo に nuget/npm を同居させられるが、URL から用途を読めるよう分ける
resource "cloudsmith_repository" "this" {
  for_each = local.repositories

  namespace       = data.cloudsmith_organization.this.slug
  name            = each.value
  slug            = each.value
  description     = "Overload Party shared ${each.key} packages"
  repository_type = "Public"
  broadcast_state = "Public"

  # provider enum に jp-tokyo が無いため、UI で選択済みの jp-tokyo を維持するため管理外にする
  lifecycle {
    ignore_changes = [storage_region]
  }
}

resource "cloudsmith_service" "publisher" {
  organization  = data.cloudsmith_organization.this.slug
  name          = "overload-party-publisher"
  description   = "publish-package workflow が OIDC で取得して package を push する SA"
  store_api_key = false
}

resource "cloudsmith_service" "reader" {
  organization  = data.cloudsmith_organization.this.slug
  name          = "overload-party-reader"
  description   = "consumer ワークフロー (dotnet restore / npm install) が OIDC で取得する SA"
  store_api_key = false
}

resource "cloudsmith_repository_privileges" "this" {
  for_each = local.repositories

  organization = data.cloudsmith_organization.this.slug
  repository   = cloudsmith_repository.this[each.key].slug

  # API key 所有者の Admin を明示しないと lockout 防止のため apply が拒否される
  user {
    privilege = "Admin"
    slug      = data.cloudsmith_user_self.current.slug
  }

  service {
    privilege = "Write"
    slug      = cloudsmith_service.publisher.slug
  }

  service {
    privilege = "Read"
    slug      = cloudsmith_service.reader.slug
  }
}

# claims が map(string) で list 値を取れないため、許可リスト方式は per-repo で OIDC config を作成して実現する。
# aud=cloudsmith を必須にして、デフォルト audience の token が誤って通らないようにする
resource "cloudsmith_oidc" "publisher" {
  for_each = toset(local.publisher_repos)

  namespace        = data.cloudsmith_organization.this.slug_perm
  name             = "github-publisher-${each.value}"
  enabled          = true
  provider_url     = "https://token.actions.githubusercontent.com"
  service_accounts = [cloudsmith_service.publisher.slug]

  claims = {
    aud        = "cloudsmith"
    repository = "${local.github_owner}/${each.value}"
  }
}

resource "cloudsmith_oidc" "reader" {
  for_each = toset(local.reader_repos)

  namespace        = data.cloudsmith_organization.this.slug_perm
  name             = "github-reader-${each.value}"
  enabled          = true
  provider_url     = "https://token.actions.githubusercontent.com"
  service_accounts = [cloudsmith_service.reader.slug]

  claims = {
    aud        = "cloudsmith"
    repository = "${local.github_owner}/${each.value}"
  }
}
