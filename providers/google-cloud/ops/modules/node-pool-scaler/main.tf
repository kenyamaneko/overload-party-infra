# node-pool-scale workflow 用 SA と WIF。
# cluster_host_project 上の権限付与は brand 側 (keyandnotes-platform) の app-iam-grants module
# に集約しているので本モジュールでは扱わない。

resource "google_service_account" "node_pool_scaler" {
  project      = var.ops_project_id
  account_id   = "gh-node-pool-scaler"
  display_name = "GitHub Actions Node Pool Scaler"
}

resource "google_service_account_iam_member" "wif" {
  service_account_id = google_service_account.node_pool_scaler.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${var.workload_identity_pool_name}/attribute.repository/${var.github_owner}/${var.github_repository}"
}
