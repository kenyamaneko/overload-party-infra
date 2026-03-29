# ゲームアセット配信:
#   - カードイラスト・スタンプ → GCS 公開バケット + Cloudflare CDN でユーザー端末に直接配信
#   - シナリオスクリプト        → GCS 非公開バケットにサーバーからアクセス（API 経由で配信）
#
# 公開バケットは Cloudflare CNAME バケットとして使用するため、
# バケット名 = サブドメイン（例: overload-party-assets-dev.keyandnotes.com）。
# Cloudflare CDN の CNAME 設定は environments/cloudflare/ で管理する。
#
# デプロイは CI から `gcloud storage cp` で行う。
# Terraform はバケットの作成のみ管理し、コンテンツのデプロイは行わない。

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

variable "asset_domain" {
  description = "Asset CDN domain (= GCS CNAME bucket name). e.g. overload-party-assets-dev.keyandnotes.com"
  type        = string
}

# ──────────────────────────────────────────────
# GCS Bucket — public (card illustrations, stamps, story art/audio)
# ──────────────────────────────────────────────
# バケット名をドメインと一致させることで、Cloudflare からの
# CNAME (→ c.storage.googleapis.com) で GCS が自動解決する。

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
# GCS Bucket — private (scenario scripts)
# ──────────────────────────────────────────────

resource "google_storage_bucket" "scenarios" {
  name                        = "${var.project_id}-scenarios"
  project                     = var.project_id
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = false
}

# ──────────────────────────────────────────────
# Outputs
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
