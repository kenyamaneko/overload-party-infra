# node-pool-scale workflow 用 SA と、resize 対象クラスタ (cluster_host_project) への cross-project grant。

resource "google_service_account" "node_pool_scaler" {
  project      = var.ops_project_id
  account_id   = "gh-node-pool-scaler"
  display_name = "GitHub Actions Node Pool Scaler"
}

resource "google_project_iam_member" "container_developer" {
  project = var.cluster_host_project
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.node_pool_scaler.email}"
}

# resize 後に kubectl wait でノード Ready を確認する get-gke-credentials のために必要。
resource "google_project_iam_member" "container_cluster_viewer" {
  project = var.cluster_host_project
  role    = "roles/container.clusterViewer"
  member  = "serviceAccount:${google_service_account.node_pool_scaler.email}"
}

resource "google_service_account_iam_member" "wif" {
  service_account_id = google_service_account.node_pool_scaler.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${var.workload_identity_pool_name}/attribute.repository/${var.github_owner}/${var.github_repository}"
}
