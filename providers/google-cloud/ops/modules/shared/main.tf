# 複数 module が共通で使う API はここに集約し、module 単位での重複宣言を避ける。
# 単一 module でしか使わない API (sqladmin / firebase 等) は各 module 側で enable する。
resource "google_project_service" "secretmanager" {
  project            = var.project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "run" {
  project            = var.project_id
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

# accessor IAM は各 consumer module (slack-commands 等) が自分の SA に対して直接付与する。
# shared で accessor をまとめると consumer module の output を引く必要があり、
# consumer は shared の API 有効化に depends_on するため循環依存になる。
# 実値は手動で投入:
#   gcloud secrets versions add slack-webhook-url --project <project_id> --data-file=- <<< "<URL>"
resource "google_secret_manager_secret" "slack_webhook_url" {
  project   = var.project_id
  secret_id = "slack-webhook-url"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}
