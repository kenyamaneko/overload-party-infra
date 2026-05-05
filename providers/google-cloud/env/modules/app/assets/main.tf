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

# overload-party-assets リポの deploy.yaml が github-ci 経由でアセットを upload する。
resource "google_storage_bucket_iam_member" "assets_ci_writer" {
  bucket = google_storage_bucket.assets.name
  role   = "roles/storage.objectAdmin"
  member = var.deploy_sa_member
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

resource "google_storage_bucket_iam_member" "scenarios_ci_writer" {
  bucket = google_storage_bucket.scenarios.name
  role   = "roles/storage.objectAdmin"
  member = var.deploy_sa_member
}
