resource "google_service_account" "accounts" {
  for_each = local.all_services

  project      = var.project_id
  account_id   = each.value
  display_name = "Overload Party ${title(each.key)}"
}

resource "google_service_account_iam_member" "workload_identity" {
  for_each = var.k8s_services

  service_account_id = google_service_account.accounts[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${local.gke_project_id}.svc.id.goog[${var.k8s_namespace}/${each.key}]"
}

