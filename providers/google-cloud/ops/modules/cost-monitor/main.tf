# ──────────────────────────────────────────────
# cost-monitor 用 cross-project IAM / API 有効化
# cost-monitor は overload-party-ops リポの GitHub Actions 上で動作し、
# 監視対象プロジェクトの Cloud SQL / Compute / GKE の状態を viewer 権限で確認する。
# ──────────────────────────────────────────────

# gcloud sql コマンド (Cloud SQL の activation_policy 確認) 実行に必要
resource "google_project_service" "sqladmin" {
  project            = var.ops_project_id
  service            = "sqladmin.googleapis.com"
  disable_on_destroy = false
}

# Cloud SQL 状態確認
resource "google_project_iam_member" "cloudsql_viewer" {
  for_each = toset(var.monitored_projects)

  project = each.value
  role    = "roles/cloudsql.viewer"
  member  = var.deploy_sa_member
}

# Static IP / PSC など Compute リソース状態確認
resource "google_project_iam_member" "compute_viewer" {
  for_each = toset(var.monitored_projects)

  project = each.value
  role    = "roles/compute.viewer"
  member  = var.deploy_sa_member
}

# GKE Deployment / Ingress 状態確認
resource "google_project_iam_member" "gke_viewer" {
  project = var.gke_project
  role    = "roles/container.viewer"
  member  = var.deploy_sa_member
}
