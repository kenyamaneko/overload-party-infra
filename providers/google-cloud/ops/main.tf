# overload-party-ops プロジェクト専用の Terraform composition。
# platform/ は keyandnotes-platform、env/{dev,stg,prod}/ は各ワークロードプロジェクトを
# 担当するが、ops プロジェクトはどちらにも属さないため独立した composition として切り出す。
# 運用系ワークロード (nightly-review / slack-commands / cost-monitor / drift-monitor) と
# その基盤 (shared module: API 有効化 + 共有 Secret 枠) をまとめて管理する。

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

  # GitHub Actions の CI/CD は keyandnotes-platform の github-ci SA に集約している。
  # overload-party-ops への cross-project IAM は platform/modules/ci-cd 側で
  # cloudrun_job_deploy_projects に "overload-party-ops" を含めることで付与済み。
  deploy_sa_member = "serviceAccount:github-ci@keyandnotes-platform.iam.gserviceaccount.com"

  # cost-monitor / drift-monitor の監視対象。
  cost_monitored_projects = [
    "overload-party-dev",
    "overload-party-stg",
  ]
  drift_monitored_projects = [
    "overload-party-dev",
    "overload-party-stg",
    "overload-party-prod",
    "overload-party-ops",
    "keyandnotes-platform",
  ]

  # slack-commands /db-start /db-stop が触る Cloud SQL のあるプロジェクト。
  cloudsql_admin_projects = [
    "overload-party-dev",
    "overload-party-stg",
  ]

  # /open-issues が横断検索する GitHub リポジトリ。
  slack_commands_repos = [
    "overload-party-common",
    "overload-party-client",
    "overload-party-battle",
    "overload-party-gateway",
    "overload-party-infra",
    "overload-party-k8s",
    "overload-party-newsfeed",
    "overload-party-analytics",
    "overload-party-ops",
  ]
}

provider "google" {
  project = local.project_id
  region  = local.region
}

# ──────────────────────────────────────────────
# shared: 複数 module が前提とする API 有効化 + 真の共有 Secret (slack-webhook-url)
# ──────────────────────────────────────────────

module "shared" {
  source = "./modules/shared"

  project_id = local.project_id
}

# ──────────────────────────────────────────────
# Cloud Run 系ワークロード
# ──────────────────────────────────────────────

module "nightly_review" {
  source = "./modules/nightly-review"

  project_id                     = local.project_id
  region                         = local.region
  deploy_sa_member               = local.deploy_sa_member
  shared_slack_webhook_secret_id = module.shared.slack_webhook_url_secret_id

  # CI (overload-party-ops リポ) が gcloud run jobs update で毎回差し替えるため、
  # TF は初回 create 用のプレースホルダのみ渡す (lifecycle.ignore_changes で drift 許容)。
  image = "gcr.io/cloudrun/placeholder"
}

module "slack_commands" {
  source = "./modules/slack-commands"

  project_id                     = local.project_id
  region                         = local.region
  shared_slack_webhook_secret_id = module.shared.slack_webhook_url_secret_id
  cloudsql_admin_projects        = local.cloudsql_admin_projects
  repos                          = local.slack_commands_repos

  # 初回プレースホルダ。CI の build-deploy-service.yaml が差し替える。
  image = "gcr.io/cloudrun/placeholder"
}

# ──────────────────────────────────────────────
# GitHub Actions で動く監視ツールの cross-project IAM
# ──────────────────────────────────────────────

module "cost_monitor" {
  source = "./modules/cost-monitor"

  ops_project_id     = local.project_id
  deploy_sa_member   = local.deploy_sa_member
  monitored_projects = local.cost_monitored_projects
  gke_project        = "keyandnotes-platform"
}

module "drift_monitor" {
  source = "./modules/drift-monitor"

  ops_project_id     = local.project_id
  deploy_sa_member   = local.deploy_sa_member
  monitored_projects = local.drift_monitored_projects
  tf_state_bucket    = "keyandnotes-tf-state"
}
