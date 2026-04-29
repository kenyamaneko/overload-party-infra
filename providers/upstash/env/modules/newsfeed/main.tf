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
  database_name = "overload-party-${var.env}-newsfeed"
  sa_email      = "overload-party-newsfeed@overload-party-${var.env}.iam.gserviceaccount.com"

  redis_secrets = {
    endpoint = "newsfeed-upstash-redis-endpoint"
    password = "newsfeed-upstash-redis-password"
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
