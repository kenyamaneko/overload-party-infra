terraform {
  required_providers {
    upstash = {
      source  = "upstash/upstash"
      version = "~> 1.5"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

locals {
  project_id    = "overload-party-${var.env}"
  database_name = "overload-party-${var.env}-matchmaking"
  sa_email      = "overload-party-matchmaking@overload-party-${var.env}.iam.gserviceaccount.com"

  redis_secrets = {
    endpoint = "matchmaking-upstash-redis-endpoint"
    password = "matchmaking-upstash-redis-password"
  }
}

resource "upstash_redis_database" "this" {
  database_name  = local.database_name
  region         = "gcp-global"
  primary_region = var.primary_region
  tls            = true
  eviction       = var.eviction
}

resource "google_project_service" "secretmanager" {
  project            = local.project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

# シークレット *リソース* のみ作成する。
# バージョン (実値) は手動で追加する:
#   gcloud secrets versions add matchmaking-upstash-redis-endpoint --project <project_id> --data-file=- <<< "<host>:<port>"
#   gcloud secrets versions add matchmaking-upstash-redis-password --project <project_id> --data-file=- <<< "<password>"
# host / port / password は Upstash コンソールまたは `terraform state show module.<name>.upstash_redis_database.this` から取得する。
resource "google_secret_manager_secret" "redis" {
  for_each = local.redis_secrets

  project   = local.project_id
  secret_id = each.value

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_iam_member" "accessor" {
  for_each = google_secret_manager_secret.redis

  project   = local.project_id
  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.sa_email}"
}
