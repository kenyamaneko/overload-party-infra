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

module "artifact_registry" {
  source = "./modules/artifact-registry"

  project_id    = local.project_id
  region        = local.region
  repository_id = "overload-party"
}

module "ci_cd" {
  source = "./modules/ci-cd"

  project_id   = local.project_id
  region       = local.region
  github_owner = "kenyamaneko"

  artifact_registry_id = module.artifact_registry.repository_id

  allowed_repositories = [
    "keyandnotes-platform",
    "overload-party-account",
    "overload-party-analytics",
    "overload-party-battle",
    "overload-party-card",
    "overload-party-client",
    "overload-party-common",
    "overload-party-gateway",
    "overload-party-infra",
    "overload-party-k8s",
    "overload-party-matchmaking",
    "overload-party-newsfeed",
    "overload-party-ops",
    "overload-party-scenario",
    "overload-party-shop",
  ]

  ci_wif_repositories = [
    "overload-party-account",
    "overload-party-analytics",
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

# 各環境プロジェクトの Cloud Run がこの AR からイメージをプルするための権限
resource "google_artifact_registry_repository_iam_member" "cloudrun_ar_reader" {
  for_each = {
    dev = "346314225010"
    ops = "1017837997433"
  }

  project    = local.project_id
  location   = local.region
  repository = module.artifact_registry.repository_id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:service-${each.value}@serverless-robot-prod.iam.gserviceaccount.com"
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

