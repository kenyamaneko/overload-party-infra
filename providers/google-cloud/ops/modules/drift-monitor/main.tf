# ──────────────────────────────────────────────
# drift-monitor 用 cross-project IAM / API 有効化
# drift-monitor は overload-party-ops リポの GitHub Actions 上で動作し、
# 監視対象プロジェクトで terraform plan を走らせて drift を検知する。
# ──────────────────────────────────────────────

# plan に viewer / state bucket 読み取り / 一部 API (firebase) が必要

# 各監視対象プロジェクトの terraform plan に必要
resource "google_project_iam_member" "viewer" {
  for_each = toset(var.monitored_projects)

  project = each.value
  role    = "roles/viewer"
  member  = var.deploy_sa_member
}

# バケット IAM ポリシーの読み取りに必要 (viewer だけでは storage.buckets.getIamPolicy が不足)
resource "google_project_iam_member" "security_reviewer" {
  for_each = toset(var.monitored_projects)

  project = each.value
  role    = "roles/iam.securityReviewer"
  member  = var.deploy_sa_member
}

# Terraform state bucket の中身を読む (init / plan で state 取得)
resource "google_storage_bucket_iam_member" "tf_state_reader" {
  bucket = var.tf_state_bucket
  role   = "roles/storage.objectViewer"
  member = var.deploy_sa_member
}

# drift-monitor が infra リポの plan を走らせる際に必要 (providers/google-cloud/env が叩く)
resource "google_project_service" "firebase" {
  project            = var.ops_project_id
  service            = "firebase.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "firebase_hosting" {
  project            = var.ops_project_id
  service            = "firebasehosting.googleapis.com"
  disable_on_destroy = false
}
