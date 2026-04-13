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
  project = "overload-party-prod"
  region  = "asia-northeast1"
}

module "infra" {
  source = "../../modules"

  project_id    = "overload-party-prod"
  region        = "asia-northeast1"
  k8s_namespace = "overload-party-prod"

  cloudsql_instance_name        = "overload-party-db"
  cloudsql_tier                 = "db-g1-small"
  database_name                 = "overload_party"
  deletion_protection           = true
  ipv4_enabled                  = false
  psc_allowed_consumer_projects = ["keyandnotes-platform"]

  firestore_location = "asia-northeast1"

  assets_bucket_name    = "overload-party-assets.keyandnotes.com"
  scenarios_bucket_name = "overload-party-prod-scenarios"
  newsfeed_bucket_name  = "overload-party-prod-newsfeed"

  deploy_sa                    = var.deploy_sa
  migration_image              = "asia-northeast1-docker.pkg.dev/keyandnotes-platform/overload-party/db-migrate:latest"
  deploy_service_account_email = "github-ci@keyandnotes-platform.iam.gserviceaccount.com"
  newsfeed_image               = "asia-northeast1-docker.pkg.dev/keyandnotes-platform/overload-party/newsfeed:latest"
}

output "cloudsql_psc_service_attachment" {
  value = module.infra.cloudsql_psc_service_attachment
}

output "cloudsql_dns_name" {
  value = module.infra.cloudsql_dns_name
}
