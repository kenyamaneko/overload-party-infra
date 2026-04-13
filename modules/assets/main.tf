# ──────────────────────────────────────────────
# 変数
# ──────────────────────────────────────────────

variable "project_id" {
  description = "Google Cloud プロジェクト ID"
  type        = string
}

variable "region" {
  description = "GCS バケットのロケーション"
  type        = string
}

variable "assets_bucket_name" {
  description = "公開アセットバケット名（CDN CNAME 用、グローバル一意。例: overload-party-assets-dev.keyandnotes.com）"
  type        = string
}

variable "scenarios_bucket_name" {
  description = "非公開シナリオスクリプトバケット名（グローバル一意）"
  type        = string
}

# ──────────────────────────────────────────────
# GCS バケット — 公開 (カードイラスト、スタンプ、ストーリーアート / 音声)
# ──────────────────────────────────────────────

resource "google_storage_bucket" "assets" {
  name                        = var.assets_bucket_name
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
  name                        = var.scenarios_bucket_name
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
  value = "https://${google_storage_bucket.assets.name}"
}

output "scenarios_bucket_name" {
  value = google_storage_bucket.scenarios.name
}

output "scenarios_bucket_url" {
  value = "https://storage.googleapis.com/${google_storage_bucket.scenarios.name}"
}
