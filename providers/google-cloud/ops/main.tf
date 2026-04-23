# overload-party-ops プロジェクト専用の Terraform composition。
# platform/ は keyandnotes-platform、env/{dev,stg,prod}/ は各ワークロードプロジェクトを
# 担当するが、ops プロジェクトはどちらにも属さないため独立した composition として切り出す。
# ここでは nightly-review Cloud Run Job など、運用系ツールの GCP リソースを集約する。

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
  project_id = "overload-party-ops"
  region     = "asia-northeast1"

  # GitHub Actions の CI/CD は keyandnotes-platform の github-ci SA に集約している。
  # overload-party-ops への cross-project IAM は platform/modules/ci-cd 側で
  # cloudrun_job_deploy_projects に "overload-party-ops" を含めることで付与済み。
  deploy_sa_member = "serviceAccount:github-ci@keyandnotes-platform.iam.gserviceaccount.com"
}

provider "google" {
  project = local.project_id
  region  = local.region
}

module "nightly_review" {
  source = "./modules/nightly-review"

  project_id       = local.project_id
  region           = local.region
  deploy_sa_member = local.deploy_sa_member
  # CI (overload-party-ops リポ) が gcloud run jobs update で毎回差し替えるため、
  # TF は初回 create 用のプレースホルダのみ渡す (lifecycle.ignore_changes で drift 許容)。
  image = "gcr.io/cloudrun/placeholder"
}
