# gcloud sql コマンド (Cloud SQL の activation_policy 確認) 実行に必要
resource "google_project_service" "sqladmin" {
  project            = var.ops_project_id
  service            = "sqladmin.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_iam_member" "cloudsql_viewer" {
  for_each = toset(var.monitored_projects)

  project = each.value
  role    = "roles/cloudsql.viewer"
  member  = var.deploy_sa_member
}

resource "google_project_iam_member" "compute_viewer" {
  for_each = toset(var.monitored_projects)

  project = each.value
  role    = "roles/compute.viewer"
  member  = var.deploy_sa_member
}
