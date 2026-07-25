# Secret Manager のシークレットリソースのみ作成する。実値のバージョンは手動で追加する:
#   gcloud secrets versions add support-slack-bot-token --data-file=- <<< "TOKEN_VALUE"

resource "google_project_service" "secretmanager" {
  project            = var.project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

locals {
  secret_ids = toset([
    "support-slack-bot-token",
    "support-sendgrid-api-key",
  ])
}

resource "google_secret_manager_secret" "support_secrets" {
  for_each = local.secret_ids

  project   = var.project_id
  secret_id = each.key

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_iam_member" "support_accessor" {
  for_each = local.secret_ids

  project   = var.project_id
  secret_id = google_secret_manager_secret.support_secrets[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.support_service_account_email}"
}
