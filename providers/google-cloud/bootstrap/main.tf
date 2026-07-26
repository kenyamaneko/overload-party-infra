terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

locals {
  project_id = "overload-party-ops"
  region     = "asia-northeast1"

  github_owner = "kenyamaneko"

  # リポ単位でしか絞らないため、このリストに入ったリポなら任意のブランチから
  # 紐付いた SA になりすませる。ブランチや environment での絞り込みは行わない。
  wif_allowed_repositories = [
    "overload-party-account",
    "overload-party-analytics",
    "overload-party-assets",
    "overload-party-battle",
    "overload-party-card",
    "overload-party-client",
    "overload-party-common",
    "overload-party-gateway",
    "overload-party-infra",
    "overload-party-k8s",
    "overload-party-matchmaking",
    "overload-party-news",
    "overload-party-newsfeed",
    "overload-party-ops",
    "overload-party-scenario",
    "overload-party-shop",
    "overload-party-support",
  ]

  # 誤って state オブジェクトを削除した際の復旧猶予 (7日)。
  tfstate_soft_delete_retention_seconds = 60 * 60 * 24 * 7
}

provider "google" {
  project = local.project_id
  region  = local.region
}

resource "google_storage_bucket" "tfstate" {
  name                        = "overload-party-tfstate"
  project                     = local.project_id
  location                    = local.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  force_destroy               = false

  versioning {
    enabled = false
  }

  soft_delete_policy {
    retention_duration_seconds = local.tfstate_soft_delete_retention_seconds
  }
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = local.project_id
  workload_identity_pool_id = "github-actions"
  display_name              = "GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = local.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  # SA 側の workloadIdentityUser 付与と二重化する defense in depth。
  # SA 側の付与ミスで意図しないリポから impersonation が通らないよう pool 入口で弾く。
  attribute_condition = "assertion.repository in [${join(", ", [for r in local.wif_allowed_repositories : "'${local.github_owner}/${r}'"])}]"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}
