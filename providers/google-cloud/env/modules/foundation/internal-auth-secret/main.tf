# Terraform はシークレットのリソースのみ作成する。実値のバージョンは手動で追加する:
#   gcloud secrets versions add internal-auth-secret --project <project_id> --data-file=- <<< "<secret>"

resource "google_project_service" "secretmanager" {
  project            = var.project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_secret_manager_secret" "internal_auth" {
  project   = var.project_id
  secret_id = "internal-auth-secret"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_iam_member" "accessor" {
  for_each = var.accessor_service_account_emails

  project   = var.project_id
  secret_id = google_secret_manager_secret.internal_auth.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${each.value}"
}
