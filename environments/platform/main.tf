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

# AR リポジトリは k8s リポで管理。ID だけ参照する。
data "google_artifact_registry_repository" "overload_party" {
  project       = local.project_id
  location      = local.region
  repository_id = "overload-party"
}

module "ci_cd" {
  source = "../../modules/ci-cd"

  project_id   = local.project_id
  region       = local.region
  github_owner = "kenyamaneko"

  artifact_registry_id = data.google_artifact_registry_repository.overload_party.repository_id

  allowed_repositories = [
    "overload-party-analytics",
    "overload-party-battle",
    "overload-party-client",
    "overload-party-common",
    "overload-party-gateway",
    "overload-party-infra",
    "overload-party-k8s",
    "overload-party-newsfeed",
    "overload-party-ops",
  ]

  ci_wif_repositories = [
    "overload-party-analytics",
    "overload-party-battle",
    "overload-party-client",
    "overload-party-common",
    "overload-party-gateway",
    "overload-party-infra",
    "overload-party-newsfeed",
    "overload-party-ops",
  ]

  terraform_wif_repositories = [
    "overload-party-infra",
    "overload-party-k8s",
  ]

  cloudfunctions_projects = ["overload-party-dev"]
  cloudrun_projects       = ["overload-party-dev"]
}

# Cloud Run in each environment project needs to pull images from this AR.
resource "google_artifact_registry_repository_iam_member" "cloudrun_ar_reader" {
  for_each = {
    dev = "346314225010"
  }

  project    = local.project_id
  location   = local.region
  repository = data.google_artifact_registry_repository.overload_party.repository_id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:service-${each.value}@serverless-robot-prod.iam.gserviceaccount.com"
}

# ---- Outputs ----

output "wif_provider" {
  value = module.ci_cd.wif_provider
}

output "ci_service_account_email" {
  value = module.ci_cd.ci_service_account_email
}

output "terraform_service_account_email" {
  value = module.ci_cd.terraform_service_account_email
}
