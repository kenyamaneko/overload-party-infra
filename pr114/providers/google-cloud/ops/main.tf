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

  deploy_sa_member      = "serviceAccount:github-ci@overload-party-ops.iam.gserviceaccount.com"
  db_migrator_sa_member = "serviceAccount:gh-db-migrator@overload-party-ops.iam.gserviceaccount.com"

  artifact_registry_cloudrun_consumer_project_numbers = {
    dev  = "346314225010"
    stg  = "352552278611"
    prod = "555166780133"
    ops  = "1017837997433"
  }

  cost_monitored_projects = [
    "overload-party-dev",
    "overload-party-stg",
  ]
  drift_monitored_projects = [
    "overload-party-dev",
    "overload-party-stg",
    "overload-party-prod",
    "overload-party-ops",
  ]

  cloudsql_admin_projects = [
    "overload-party-dev",
    "overload-party-stg",
  ]

  workload_identity_pool_name     = "projects/248288258659/locations/global/workloadIdentityPools/github-actions"
  workload_identity_pool_name_new = "projects/1017837997433/locations/global/workloadIdentityPools/github-actions"

  billing_account_id = "019A0B-9A103A-B4C602"
  monthly_budget_jpy = 200
}

provider "google" {
  project = local.project_id
  region  = local.region
}

module "shared" {
  source = "./modules/shared"

  project_id = local.project_id
}

module "artifact_registry" {
  source = "./modules/artifact-registry"

  project_id    = local.project_id
  region        = local.region
  repository_id = "overload-party"

  cloudrun_consumer_project_numbers = local.artifact_registry_cloudrun_consumer_project_numbers

  writer_members = [
    local.deploy_sa_member,
    local.db_migrator_sa_member,
  ]
}

module "budget" {
  source = "./modules/budget"

  project_id         = local.project_id
  billing_account_id = local.billing_account_id
  monthly_budget_jpy = local.monthly_budget_jpy
}

module "cost_monitor" {
  source = "./modules/cost-monitor"

  ops_project_id     = local.project_id
  deploy_sa_member   = local.deploy_sa_member
  monitored_projects = local.cost_monitored_projects
}

module "drift_monitor" {
  source = "./modules/drift-monitor"

  ops_project_id     = local.project_id
  deploy_sa_member   = local.deploy_sa_member
  monitored_projects = local.drift_monitored_projects
}

module "ci_cd" {
  source = "./modules/ci-cd"

  project_id                      = local.project_id
  github_owner                    = "kenyamaneko"
  workload_identity_pool_name     = local.workload_identity_pool_name
  workload_identity_pool_name_new = local.workload_identity_pool_name_new

  ci_wif_repositories = [
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
    "overload-party-news",
    "overload-party-newsfeed",
    "overload-party-ops",
    "overload-party-scenario",
    "overload-party-shop",
    "overload-party-support",
  ]

  terraform_deployer_wif_repositories = [
    "overload-party-infra",
  ]

  cloudsql_operator_wif_repositories = [
    "overload-party-infra",
  ]

  db_migrator_wif_repositories = [
    "overload-party-ops",
  ]

  db_migrator_target_projects = [
    "overload-party-dev",
    "overload-party-stg",
  ]

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
