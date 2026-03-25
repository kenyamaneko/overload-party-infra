# ゲームアセット配信:
#   - カードイラスト・スタンプ → Firebase Hosting (CDN) でユーザー端末に直接配信
#   - シナリオスクリプト        → GCS バケットにサーバーからアクセス（API 経由で配信）
#
# Firebase Hosting 制約: 1 ファイルあたり 2 GB / 無料枠 ストレージ 10 GB。
# 上限が近づいたら GCS + Cloud CDN 構成への移行を検討する。
#
# デプロイは CI から `firebase deploy --only hosting:<site_id>` で行う。
# Terraform はサイト・バケットの作成のみ管理し、コンテンツのデプロイは行わない。

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
# APIs
# ──────────────────────────────────────────────

resource "google_project_service" "firebase" {
  project = var.project_id
  service = "firebase.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "firebase_hosting" {
  project = var.project_id
  service = "firebasehosting.googleapis.com"

  disable_on_destroy = false
}

# ──────────────────────────────────────────────
# Firebase Hosting Site (card illustrations, stamps)
# ──────────────────────────────────────────────

resource "google_firebase_hosting_site" "assets" {
  provider = google-beta
  project  = var.project_id
  site_id  = "${var.project_id}-assets"

  depends_on = [
    google_project_service.firebase,
    google_project_service.firebase_hosting,
  ]
}

# ──────────────────────────────────────────────
# GCS Bucket (scenario scripts)
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

output "site_id" {
  value = google_firebase_hosting_site.assets.site_id
}

output "default_url" {
  value = google_firebase_hosting_site.assets.default_url
}

output "bucket_name" {
  value = google_storage_bucket.scenarios.name
}

output "bucket_url" {
  value = "https://storage.googleapis.com/${google_storage_bucket.scenarios.name}"
}
