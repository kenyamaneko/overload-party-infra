# ──────────────────────────────────────────────
# 内部認証共有鍵 (HS256) の Secret Manager シークレット
# ──────────────────────────────────────────────
# Terraform が作るのは 枠 のみ。バージョン (実値) は手動で追加する:
#   gcloud secrets versions add internal-auth-secret --project <project_id> --data-file=- <<< "<secret>"
#
# 利用者 identity 伝播は引き続きこの共有鍵で行う。署名方式を非対称鍵へ置き換える再設計は
# 別ワークストリームで進行中のため、本 module は既存 HS256 鍵を Secret Manager 化するに留める。

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
