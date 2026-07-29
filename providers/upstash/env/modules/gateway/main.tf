# Cloud Run が起動時にシークレットを読むため、値の投入前にリビジョンを作ると起動に失敗する。

terraform {
  required_providers {
    upstash = {
      source  = "upstash/upstash"
      version = "~> 1.5"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

locals {
  project_id    = "overload-party-${var.env}"
  database_name = "overload-party-${var.env}-gateway"
  sa_email      = "overload-party-gateway@overload-party-${var.env}.iam.gserviceaccount.com"
  secret_id     = "gateway-upstash-redis-url"
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

resource "google_secret_manager_secret" "redis_url" {
  project   = local.project_id
  secret_id = local.secret_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_iam_member" "accessor" {
  project   = local.project_id
  secret_id = google_secret_manager_secret.redis_url.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.sa_email}"
}
