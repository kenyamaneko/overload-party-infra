# Terraform はシークレットのリソースのみ作成する。実値のバージョンは手動で追加する:
#   gcloud secrets versions add gateway-alert-slack-token --project <project_id> --data-file=- <<< "<Slack app の Bot User OAuth Token>"

resource "google_project_service" "secretmanager" {
  project            = var.project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_secret_manager_secret" "slack_auth_token" {
  project   = var.project_id
  secret_id = "gateway-alert-slack-token"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

# google_monitoring_notification_channel の sensitive_labels.auth_token は値そのものを要求するため、
# Secret Manager からバージョン値を読んで渡す。値がまだ投入されていない環境では、この data source の
# 解決に失敗して apply がエラーになる (シークレット未投入の状態を明示的に検出するため意図した挙動)。
data "google_secret_manager_secret_version" "slack_auth_token" {
  project = var.project_id
  secret  = google_secret_manager_secret.slack_auth_token.secret_id
}

resource "google_monitoring_notification_channel" "slack" {
  project      = var.project_id
  display_name = "gateway alerts (Slack)"
  type         = "slack"

  labels = {
    channel_name = var.alert_slack_channel_name
  }

  sensitive_labels {
    auth_token = data.google_secret_manager_secret_version.slack_auth_token.secret_data
  }

  depends_on = [google_project_service.monitoring]
}
