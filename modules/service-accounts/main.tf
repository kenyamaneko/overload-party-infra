resource "google_service_account" "accounts" {
  for_each = var.services

  project      = var.project_id
  account_id   = each.value
  display_name = "Overload Party ${title(each.key)}"
}

resource "google_service_account_iam_member" "workload_identity" {
  for_each = var.services

  service_account_id = google_service_account.accounts[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${local.gke_project_id}.svc.id.goog[${var.k8s_namespace}/${each.key}]"
}

resource "google_project_iam_member" "cloudsql_client" {
  for_each = var.db_services

  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.accounts[each.key].email}"
}

resource "google_project_iam_member" "cloudsql_instance_user" {
  for_each = var.db_services

  project = var.project_id
  role    = "roles/cloudsql.instanceUser"
  member  = "serviceAccount:${google_service_account.accounts[each.key].email}"
}
