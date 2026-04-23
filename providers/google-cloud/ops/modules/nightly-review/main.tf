locals {
  job_name = "nightly-review"

  # 外部サービス (Anthropic / GitHub / Slack) への資格情報は個別シークレットで管理する。
  # 枠だけを Terraform が持ち、バージョン (実値) は運用者が手で投入する。
  secret_ids = {
    anthropic_api_key = "nightly-review-anthropic-key"
    github_token      = "nightly-review-gh-pat"
    slack_webhook_url = "nightly-review-slack-webhook"
  }

  # コンテナ env 名 → 参照先シークレット ID の対応。
  env_to_secret = {
    ANTHROPIC_API_KEY = local.secret_ids.anthropic_api_key
    GITHUB_TOKEN      = local.secret_ids.github_token
    SLACK_WEBHOOK_URL = local.secret_ids.slack_webhook_url
  }
}

# ──────────────────────────────────────────────
# API 有効化
# ──────────────────────────────────────────────

resource "google_project_service" "run" {
  project            = var.project_id
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "secretmanager" {
  project            = var.project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

# ──────────────────────────────────────────────
# nightly-review 用 Secret Manager シークレット
# Terraform が作るのは 枠 のみ。バージョン (実値) は手動で追加する:
#   gcloud secrets versions add nightly-review-anthropic-key  --project <project_id> --data-file=- <<< "<ANTHROPIC_API_KEY>"
#   gcloud secrets versions add nightly-review-gh-pat         --project <project_id> --data-file=- <<< "<GITHUB_PAT>"
#   gcloud secrets versions add nightly-review-slack-webhook  --project <project_id> --data-file=- <<< "<SLACK_WEBHOOK_URL>"
# ──────────────────────────────────────────────

resource "google_secret_manager_secret" "nightly_review" {
  for_each = local.secret_ids

  project   = var.project_id
  secret_id = each.value

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

# ──────────────────────────────────────────────
# Cloud Run Job 用サービスアカウント
# ──────────────────────────────────────────────

resource "google_service_account" "nightly_reviewer" {
  project      = var.project_id
  account_id   = "nightly-reviewer"
  display_name = "Nightly Review (Cloud Run Job)"
}

# プロジェクト全体に secretAccessor を広げず、対象シークレットだけに限定して
# 付与する (最小権限原則)。
resource "google_secret_manager_secret_iam_member" "nightly_reviewer_accessor" {
  for_each = local.secret_ids

  project   = var.project_id
  secret_id = google_secret_manager_secret.nightly_review[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.nightly_reviewer.email}"
}

# ──────────────────────────────────────────────
# Cloud Run v2 ジョブ
# nightly-review は github.com / api.anthropic.com / hooks.slack.com への外部 HTTPS
# しか叩かないため VPC アクセスは不要。max_retries = 0 は Python 側が 429 を自前で
# リトライするため Cloud Run のリトライと二重にならないようにするのが目的。
# ──────────────────────────────────────────────

resource "google_cloud_run_v2_job" "nightly_review" {
  name                = local.job_name
  project             = var.project_id
  location            = var.region
  deletion_protection = false

  # CI/CD がイメージタグを直接更新するため drift を許容する。
  lifecycle {
    ignore_changes = [template[0].template[0].containers[0].image]
  }

  template {
    task_count = 1

    template {
      service_account = google_service_account.nightly_reviewer.email
      max_retries     = 0
      timeout         = "1800s"

      containers {
        image = var.image

        dynamic "env" {
          for_each = local.env_to_secret
          content {
            name = env.key
            value_source {
              secret_key_ref {
                secret  = env.value
                version = "latest"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    google_project_service.run,
    google_secret_manager_secret_iam_member.nightly_reviewer_accessor,
  ]
}

# ──────────────────────────────────────────────
# デプロイ SA にジョブ更新・実行権限、およびジョブ SA への actAs 権限を付与
# ──────────────────────────────────────────────

resource "google_cloud_run_v2_job_iam_member" "deploy_job_updater" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_job.nightly_review.name
  role     = "roles/run.developer"
  member   = var.deploy_sa_member
}

resource "google_cloud_run_v2_job_iam_member" "deploy_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_job.nightly_review.name
  role     = "roles/run.invoker"
  member   = var.deploy_sa_member
}

resource "google_service_account_iam_member" "deploy_impersonate_nightly_reviewer" {
  service_account_id = google_service_account.nightly_reviewer.name
  role               = "roles/iam.serviceAccountUser"
  member             = var.deploy_sa_member
}
