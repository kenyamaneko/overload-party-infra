# node-pool-scale workflow 専用 GSA。
# nodepool は app 所有 (ADR-045) なので、scale 操作も本リポの workflow が
# WIF 経由でこの SA を impersonate して実行する。
# SA 自体は overload-party-ops プロジェクトに置き、resize 対象クラスタは
# brand プロジェクト (var.cluster_host_project) なので IAM grant は cross-project。

resource "google_service_account" "node_pool_scaler" {
  project      = var.ops_project_id
  account_id   = "gh-node-pool-scaler"
  display_name = "GitHub Actions Node Pool Scaler"
}

# node pool resize 権限。grant 先プロジェクトは brand 側 cluster_host_project。
resource "google_project_iam_member" "container_developer" {
  project = var.cluster_host_project
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.node_pool_scaler.email}"
}

# resize 後に kubectl wait でノード Ready を確認するため、get-gke-credentials の
# 呼び出しに必要な権限を付与する。
resource "google_project_iam_member" "container_cluster_viewer" {
  project = var.cluster_host_project
  role    = "roles/container.clusterViewer"
  member  = "serviceAccount:${google_service_account.node_pool_scaler.email}"
}

# WIF: 指定リポ (本 workflow を持つ overload-party-infra) からだけ impersonate 可能にする。
resource "google_service_account_iam_member" "wif" {
  service_account_id = google_service_account.node_pool_scaler.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${var.workload_identity_pool_name}/attribute.repository/${var.github_owner}/${var.github_repository}"
}
