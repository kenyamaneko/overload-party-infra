locals {
  service_name = "slack-commands"

  # この module が自モジュール専用 Secret の枠を所有する。実値は手動で投入:
  #   gcloud secrets versions add slack-signing-secret              --project <project_id> --data-file=- <<< "<SIGNING_SECRET>"
  #   gcloud secrets versions add slack-commands-dispatch-secret    --project <project_id> --data-file=- <<< "<DISPATCH>"
  #   gcloud secrets versions add github-pat-slack-commands         --project <project_id> --data-file=- <<< "<PAT>"
  module_owned_secret_ids = {
    slack_signing_secret = "slack-signing-secret"
    dispatch_secret      = "slack-commands-dispatch-secret"
    github_token         = "github-pat-slack-commands"
  }

  # Cloud Run の SA が secretAccessor を必要とする Secret (slack_signing_secret は
  # Cloudflare Worker 側で検証するため Cloud Run は読まない)。
  sa_accessible_secret_keys = ["dispatch_secret", "github_token"]
}

# ──────────────────────────────────────────────
# 自モジュール所有 Secret (枠のみ、バージョンは手動投入)
# ──────────────────────────────────────────────

resource "google_secret_manager_secret" "slack_commands" {
  for_each = local.module_owned_secret_ids

  project   = var.project_id
  secret_id = each.value

  replication {
    auto {}
  }
}

# ──────────────────────────────────────────────
# Cloud Run Service 用サービスアカウント
# ──────────────────────────────────────────────

resource "google_service_account" "slack_commands" {
  project      = var.project_id
  account_id   = "slack-commands"
  display_name = "Slack Commands Service SA"
}

resource "google_secret_manager_secret_iam_member" "slack_commands_accessor" {
  for_each = toset(local.sa_accessible_secret_keys)

  project   = var.project_id
  secret_id = google_secret_manager_secret.slack_commands[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.slack_commands.email}"
}

# shared module 所有の slack-webhook-url への accessor。slack-commands SA 単体に限定。
resource "google_secret_manager_secret_iam_member" "shared_slack_webhook_accessor" {
  project   = var.project_id
  secret_id = var.shared_slack_webhook_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.slack_commands.email}"
}

# /db-start /db-stop が各プロジェクトの Cloud SQL を停止/起動するため、
# cloudsql.admin を監視対象プロジェクトに横断付与する。
resource "google_project_iam_member" "slack_commands_cloudsql_admin" {
  for_each = toset(var.cloudsql_admin_projects)

  project = each.value
  role    = "roles/cloudsql.admin"
  member  = "serviceAccount:${google_service_account.slack_commands.email}"
}

# ──────────────────────────────────────────────
# Cloud Run v2 Service
# ──────────────────────────────────────────────

resource "google_cloud_run_v2_service" "slack_commands" {
  name     = local.service_name
  project  = var.project_id
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  lifecycle {
    # CI/CD がイメージタグを直接更新するため image の drift は許容。
    # client / client_version は gcloud CLI 等での apply 時に自動付与される metadata で
    # Terraform では管理しない。
    ignore_changes = [
      template[0].containers[0].image,
      client,
      client_version,
    ]
  }

  template {
    service_account = google_service_account.slack_commands.email

    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }

    containers {
      image = var.image

      ports {
        container_port = 8080
      }

      env {
        name = "GITHUB_TOKEN"
        value_source {
          secret_key_ref {
            secret  = local.module_owned_secret_ids.github_token
            version = "latest"
          }
        }
      }

      env {
        name = "DISPATCH_SECRET"
        value_source {
          secret_key_ref {
            secret  = local.module_owned_secret_ids.dispatch_secret
            version = "latest"
          }
        }
      }

      env {
        name  = "REPOS_JSON"
        value = jsonencode(var.repos)
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      startup_probe {
        http_get {
          path = "/health"
        }
      }
    }
  }

  depends_on = [google_secret_manager_secret_iam_member.slack_commands_accessor]
}

# Cloudflare Worker からの未認証リクエストを許可 (認証は DISPATCH_SECRET で行う)
resource "google_cloud_run_v2_service_iam_member" "allow_unauthenticated" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.slack_commands.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
