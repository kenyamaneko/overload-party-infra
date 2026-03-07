# Static assets bucket for card illustrations and stamps.
# CDN は Cloudflare で GCS バケットを Origin として設定する。

# ──────────────────────────────────────────────
# Variables
# ──────────────────────────────────────────────

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCS bucket location"
  type        = string
}

# ──────────────────────────────────────────────
# GCS Bucket
# ──────────────────────────────────────────────

resource "google_storage_bucket" "assets" {
  name                        = "${var.project_id}-assets"
  project                     = var.project_id
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = false

  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD"]
    response_header = ["Content-Type", "Cache-Control"]
    max_age_seconds = 3600
  }
}

resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.assets.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# ──────────────────────────────────────────────
# Outputs
# ──────────────────────────────────────────────

output "bucket_name" {
  value = google_storage_bucket.assets.name
}

output "bucket_url" {
  value = "https://storage.googleapis.com/${google_storage_bucket.assets.name}"
}
