# ──────────────────────────────────────────────
# overload-party-ops プロジェクトの基盤 API 有効化
# ops 配下の複数 module (nightly-review / slack-commands / cost-monitor / drift-monitor)
# が前提とする API を shared に集約し、module 単位での重複宣言を避ける。
# 単一 module でしか使わない API (sqladmin / firebase 等) は各 module 側で enable する。
# ──────────────────────────────────────────────

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

# ──────────────────────────────────────────────
# slack-webhook-url: 複数 consumer が同じ webhook URL を叩く「真の共有 Secret」
# 枠のみ管理し、バージョン (実値) は手動で投入する:
#   gcloud secrets versions add slack-webhook-url --project <project_id> --data-file=- <<< "<URL>"
#
# accessor IAM は各 consumer module (slack-commands / nightly-review) が自分の SA に対して
# 直接付与する。shared で accessor をまとめようとすると consumer module の output を引く
# 必要があり、consumer は shared の API 有効化に depends_on するため循環依存になる。
# ──────────────────────────────────────────────

resource "google_secret_manager_secret" "slack_webhook_url" {
  project   = var.project_id
  secret_id = "slack-webhook-url"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}
