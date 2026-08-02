# battle が card の HTTP API からマスターデータを読むと、battle に card の invoker を
# 付与する必要が生じて Terraform の依存が循環するため、GCS を介して受け渡す。

resource "google_storage_bucket" "master_data" {
  name                        = var.bucket_name
  project                     = var.project_id
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = false
}

# overload-party-card リポの deploy.yaml が github-ci 経由でマスターデータを upload する。
resource "google_storage_bucket_iam_member" "master_data_ci_writer" {
  bucket = google_storage_bucket.master_data.name
  role   = "roles/storage.objectAdmin"
  member = var.deploy_sa_member
}

resource "google_storage_bucket_iam_member" "master_data_battle_reader" {
  bucket = google_storage_bucket.master_data.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${var.battle_service_account_email}"
}
