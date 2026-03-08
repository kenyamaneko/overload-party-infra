# Google Service Account for application workloads (gateway, battle)
resource "google_service_account" "game_server" {
  project      = var.project_id
  account_id   = var.service_account_id
  display_name = "Overload Party App"
}

# Allow GSA to access Cloud SQL
resource "google_project_iam_member" "cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.game_server.email}"
}

# Allow GSA to use IAM database authentication
resource "google_project_iam_member" "cloudsql_instance_user" {
  project = var.project_id
  role    = "roles/cloudsql.instanceUser"
  member  = "serviceAccount:${google_service_account.game_server.email}"
}

# Workload Identity: allow K8s SA to impersonate this GSA
resource "google_service_account_iam_member" "workload_identity" {
  count              = var.gke_project_id != "" ? 1 : 0
  service_account_id = google_service_account.game_server.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.gke_project_id}.svc.id.goog[${var.k8s_namespace}/${var.k8s_service_account}]"
}

# Allow GitHub Actions deploy SA to start/stop Cloud SQL instances
resource "google_project_iam_member" "deploy_sa_cloudsql_admin" {
  count   = var.deploy_service_account_email != "" ? 1 : 0
  project = var.project_id
  role    = "roles/cloudsql.admin"
  member  = "serviceAccount:${var.deploy_service_account_email}"
}
