# ──────────────────────────────────────────────
# 変数
# ──────────────────────────────────────────────

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCS bucket location"
  type        = string
}

variable "asset_domain" {
  description = "Asset CDN domain (= GCS CNAME bucket name). e.g. overload-party-assets-dev.keyandnotes.com"
  type        = string
}

# ──────────────────────────────────────────────
# GCS バケット — 公開 (カードイラスト、スタンプ、ストーリーアート / 音声)
# ──────────────────────────────────────────────

resource "google_storage_bucket" "assets" {
  name                        = var.asset_domain
  project                     = var.project_id
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = false
}

resource "google_storage_bucket_iam_member" "assets_public" {
  bucket = google_storage_bucket.assets.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# ──────────────────────────────────────────────
# GCS バケット — 非公開 (シナリオスクリプト)
# ──────────────────────────────────────────────

resource "google_storage_bucket" "scenarios" {
  name                        = "${var.project_id}-scenarios"
  project                     = var.project_id
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = false
}

# ──────────────────────────────────────────────
# 出力
# ──────────────────────────────────────────────

output "assets_bucket_name" {
  value = google_storage_bucket.assets.name
}

output "assets_bucket_url" {
  value = "https://${var.asset_domain}"
}

output "scenarios_bucket_name" {
  value = google_storage_bucket.scenarios.name
}

output "scenarios_bucket_url" {
  value = "https://storage.googleapis.com/${google_storage_bucket.scenarios.name}"
}
