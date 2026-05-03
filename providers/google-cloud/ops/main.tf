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

  deploy_sa_member = "serviceAccount:github-ci@overload-party-ops.iam.gserviceaccount.com"

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

module "shared" {
  source = "./modules/shared"

  project_id = local.project_id
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

  project_id                  = local.project_id
  github_owner                = "kenyamaneko"
  workload_identity_pool_name = "projects/248288258659/locations/global/workloadIdentityPools/github-actions"

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
    "overload-party-newsfeed",
    "overload-party-ops",
    "overload-party-scenario",
    "overload-party-shop",
  ]

  terraform_deployer_wif_repositories = [
    "overload-party-infra",
    "overload-party-k8s",
  ]

  gke_deployer_wif_repositories = [
    "overload-party-k8s",
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
