# ──────────────────────────────────────────────
# Shop IAP シークレット (Secret Manager)
# ──────────────────────────────────────────────
# Secret Manager のシークレット *リソース* のみ作成する。
# シークレット *バージョン* (実際のクレデンシャル値) は手動で追加する:
#   gcloud secrets versions add shop-apple-key-id --data-file=- <<< "KEY_ID_VALUE"

resource "google_project_service" "secretmanager" {
  project            = var.project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

locals {
  secret_ids = toset([
    "shop-apple-key-id",
    "shop-apple-issuer-id",
    "shop-apple-bundle-id",
    "shop-apple-private-key",
    "shop-google-package-name",
  ])
}

resource "google_secret_manager_secret" "shop_secrets" {
  for_each = local.secret_ids

  project   = var.project_id
  secret_id = each.key

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_iam_member" "shop_accessor" {
  for_each = local.secret_ids

  project   = var.project_id
  secret_id = google_secret_manager_secret.shop_secrets[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.shop_service_account_email}"
}
