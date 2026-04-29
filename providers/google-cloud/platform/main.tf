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
  project_id = "keyandnotes-platform"
  region     = "asia-northeast1"
}

provider "google" {
  project = local.project_id
  region  = local.region
}

module "ci_cd" {
  source = "./modules/ci-cd"

  project_id = local.project_id

  analytics_deploy_projects    = ["overload-party-dev"]
  cloudrun_job_deploy_projects = ["overload-party-dev", "overload-party-ops"]

  terraform_managed_projects = [
    "overload-party-dev",
    "overload-party-stg",
    "overload-party-prod",
    "overload-party-ops",
  ]
  cloudsql_lifecycle_projects = [
    "overload-party-dev",
    "overload-party-stg",
  ]
}

# PSC エンドポイントは物理的に consumer 側 VPC (keyandnotes-platform) にしか置けないが、
# state 所有権は env/ 側に寄せる方が一貫性があり、env apply だけで配線が完結する。
# state mv を伴うため全 env が安定稼働してから移行する。それまでは platform/ 所有を維持する。
module "psc_cloudsql_dev" {
  source = "./modules/psc-cloudsql"

  project_id             = local.project_id
  region                 = local.region
  network                = "default"
  env_name               = "dev"
  cloudsql_project_id    = "overload-party-dev"
  cloudsql_instance_name = "overload-party-db"
}

module "psc_cloudsql_stg" {
  source = "./modules/psc-cloudsql"

  project_id             = local.project_id
  region                 = local.region
  network                = "default"
  env_name               = "stg"
  cloudsql_project_id    = "overload-party-stg"
  cloudsql_instance_name = "overload-party-db"
}

# prod Cloud SQL が作成されたタイミングで有効化する
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

