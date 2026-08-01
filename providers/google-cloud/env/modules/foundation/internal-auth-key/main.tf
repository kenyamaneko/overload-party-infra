# Terraform はシークレットのリソースのみ作成する。実値のバージョンは手動で追加する:
#   gcloud secrets versions add internal-auth-private-key --project <project_id> --data-file=<key.pem>
#
# 鍵は env ごとに独立させる。1 つ漏れても他の env のトークンを偽造できないようにするため。

resource "google_project_service" "secretmanager" {
  project            = var.project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_secret_manager_secret" "internal_auth" {
  project   = var.project_id
  secret_id = "internal-auth-private-key"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

# 署名するのは gateway だけで、下流は公開鍵で検証する。秘密鍵を読めるのは gateway に限る。
resource "google_secret_manager_secret_iam_member" "accessor" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.internal_auth.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.signer_service_account_email}"
}
