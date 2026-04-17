terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

locals {
  project_id = "keyandnotes-platform"
  region     = "asia-northeast1"
}

provider "google" {
  project = local.project_id
  region  = local.region
}

# Artifact Registry 本体と WIF pool / github-ci SA および Cloud Run サービスエージェントへの
# reader 付与は keyandnotes-platform リポで所有する。
# ここでは overload-party スコープの SA（terraform-deployer / github-deploy /
# cloudsql-operator）と、github-ci への cross-project IAM 付与のみを扱う。

module "ci_cd" {
  source = "./modules/ci-cd"

  project_id   = local.project_id
  github_owner = "kenyamaneko"

  terraform_wif_repositories = [
    "keyandnotes-platform",
    "overload-party-infra",
    "overload-party-k8s",
  ]

  deploy_wif_repositories = [
    "overload-party-k8s",
  ]

  # cloudsql-activation workflow は infra リポに配置するため、infra だけ許可。
  cloudsql_operator_wif_repositories = [
    "overload-party-infra",
  ]

  cloudfunctions_projects = ["overload-party-dev"]
  cloudrun_projects       = ["overload-party-dev", "overload-party-ops"]

  terraform_editor_projects = [
    "keyandnotes-platform",
    "overload-party-dev",
    "overload-party-stg",
    "overload-party-prod",
  ]
  cloudsql_admin_projects = [
    "overload-party-dev",
    "overload-party-stg",
  ]
}

# ──────────────────────────────────────────────
# Cloud SQL 用 PSC エンドポイント (環境別)
# ──────────────────────────────────────────────

module "psc_cloudsql_dev" {
  source = "./modules/psc-cloudsql"

  project_id             = local.project_id
  region                 = local.region
  network                = "default"
  env_name               = "dev"
  cloudsql_project_id    = "overload-party-dev"
  cloudsql_instance_name = "overload-party-db"
}

# stg / prod の PSC は overload-party-{stg,prod} プロジェクトに Cloud SQL
# インスタンスが未作成のため data lookup が失敗する。
# 本番準備時に env/{stg,prod} を apply して SQL を作ってから戻す。
# module "psc_cloudsql_stg" {
#   source = "./modules/psc-cloudsql"
#
#   project_id             = local.project_id
#   region                 = local.region
#   network                = "default"
#   env_name               = "stg"
#   cloudsql_project_id    = "overload-party-stg"
#   cloudsql_instance_name = "overload-party-db"
# }
#
# module "psc_cloudsql_prod" {
#   source = "./modules/psc-cloudsql"
#
#   project_id             = local.project_id
#   region                 = local.region
#   network                = "default"
#   env_name               = "prod"
#   cloudsql_project_id    = "overload-party-prod"
#   cloudsql_instance_name = "overload-party-db"
# }

