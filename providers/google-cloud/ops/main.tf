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

module "gke_nodepools" {
  source = "./modules/gke-nodepools"

  cluster_host_project = "keyandnotes-platform"
  cluster_name         = "keyandnotes-main"
  cluster_location     = "asia-northeast1-a"

  # stg は prod と同スペックで本番再現性を確保。
  node_pools = {
    dev = {
      machine_type      = "e2-medium"
      node_count        = 0
      ignore_node_count = true
      labels            = {}
      taints            = []
    }
    stg = {
      machine_type      = "e2-standard-2"
      node_count        = 0
      ignore_node_count = true
      labels            = {}
      taints            = []
    }
    # 本稼働開始まで 0 ノードで運用。開始時に node_count = 1 に戻す。
    prod = {
      machine_type      = "e2-standard-2"
      node_count        = 0
      ignore_node_count = false
      labels            = {}
      taints            = []
    }
  }
}

module "node_pool_scaler" {
  source = "./modules/node-pool-scaler"

  ops_project_id              = local.project_id
  github_owner                = "kenyamaneko"
  github_repository           = "overload-party-infra"
  workload_identity_pool_name = "projects/248288258659/locations/global/workloadIdentityPools/github-actions"
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
    "overload-party-news",
    "overload-party-newsfeed",
    "overload-party-ops",
    "overload-party-scenario",
    "overload-party-shop",
    "overload-party-support",
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

# GitHub Actions repo variable NODE_POOL_SCALER_SERVICE_ACCOUNT に手動投入する用途。
output "node_pool_scaler_sa_email" {
  value = module.node_pool_scaler.service_account_email
}
