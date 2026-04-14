terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = "overload-party-dev"
  region  = "asia-northeast1"
}

module "infra" {
  source = "../modules"

  project_id    = "overload-party-dev"
  region        = "asia-northeast1"
  k8s_namespace = "overload-party-dev"

  cloudsql_instance_name        = "overload-party-db"
  cloudsql_tier                 = "db-g1-small"
  database_name                 = "overload_party"
  deletion_protection           = false
  ipv4_enabled                  = false
  psc_allowed_consumer_projects = ["keyandnotes-platform"]

  firestore_location = "asia-northeast1"

  assets_bucket_name    = "overload-party-assets-dev.keyandnotes.com"
  scenarios_bucket_name = "overload-party-dev-scenarios"
  newsfeed_bucket_name  = "overload-party-dev-newsfeed"

  deploy_sa                    = var.deploy_sa
  migration_image              = "asia-northeast1-docker.pkg.dev/keyandnotes-platform/overload-party/db-migrate:latest"
  deploy_service_account_email = "github-ci@keyandnotes-platform.iam.gserviceaccount.com"
  newsfeed_image               = "asia-northeast1-docker.pkg.dev/keyandnotes-platform/overload-party/newsfeed:latest"
}

# orchestration レイヤのトップレベルリソースをサブモジュールに吸収したことによる state アドレス書き換え
moved {
  from = module.infra.google_service_account.newsfeed[0]
  to   = module.infra.module.service_accounts.google_service_account.accounts["newsfeed"]
}

moved {
  from = module.infra.google_project_iam_member.deploy_cloudsql_editor[0]
  to   = module.infra.module.database.google_project_iam_member.deploy_cloudsql_editor[0]
}

moved {
  from = module.infra.module.newsfeed[0]
  to   = module.infra.module.newsfeed
}

