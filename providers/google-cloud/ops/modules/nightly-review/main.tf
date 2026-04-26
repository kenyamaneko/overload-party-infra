locals {
  job_name = "nightly-review"

  # この module が自モジュール専用 Secret の枠を所有する。実値は手動で投入:
  #   gcloud secrets versions add nightly-review-anthropic-key --project <project_id> --data-file=- <<< "<ANTHROPIC_API_KEY>"
  #   gcloud secrets versions add github-pat-nightly-review    --project <project_id> --data-file=- <<< "<GITHUB_PAT>"
  module_owned_secret_ids = {
    anthropic_api_key = "nightly-review-anthropic-key"
    github_token      = "github-pat-nightly-review"
  }

  # slack-webhook-url は shared module が枠を所有する「真の共有 Secret」。
  # ここでは accessor IAM を nightly_reviewer SA に付与するためだけに参照する。
  env_to_secret = {
    ANTHROPIC_API_KEY = local.module_owned_secret_ids.anthropic_api_key
    GITHUB_TOKEN      = local.module_owned_secret_ids.github_token
    SLACK_WEBHOOK_URL = var.shared_slack_webhook_secret_id
  }
}

# ──────────────────────────────────────────────
# 自モジュール所有 Secret (枠のみ、バージョンは手動投入)
# API 有効化 (secretmanager / run) は ops/modules/shared が一元管理し、
# composition 側の module depends_on で先行実行を保証している。
# ──────────────────────────────────────────────

resource "google_secret_manager_secret" "nightly_review" {
  for_each = local.module_owned_secret_ids

  project   = var.project_id
  secret_id = each.value

  replication {
    auto {}
  }
}

# ──────────────────────────────────────────────
# Cloud Run Job 用サービスアカウント
# ──────────────────────────────────────────────

resource "google_service_account" "nightly_reviewer" {
  project      = var.project_id
  account_id   = "nightly-reviewer"
  display_name = "Nightly Review (Cloud Run Job)"
}

# 自 module 所有 Secret への accessor。プロジェクト全体に secretAccessor を広げず
# 対象シークレットだけに限定する (最小権限原則)。
resource "google_secret_manager_secret_iam_member" "nightly_reviewer_accessor" {
  for_each = local.module_owned_secret_ids

  project   = var.project_id
  secret_id = google_secret_manager_secret.nightly_review[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.nightly_reviewer.email}"
}

# shared module 所有の slack-webhook-url への accessor。shared 側で枠を持つ ID を
# var 経由で受け取り、nightly_reviewer SA 単体に限定して付与する。
resource "google_secret_manager_secret_iam_member" "shared_slack_webhook_accessor" {
  project   = var.project_id
  secret_id = var.shared_slack_webhook_secret_id
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

        # Cloud Run Jobs が自動注入するのは CLOUD_RUN_EXECUTION / CLOUD_RUN_JOB /
        # CLOUD_RUN_TASK_* のみ。GOOGLE_CLOUD_PROJECT は注入されないため、
        # review.py が Slack 通知に貼る Cloud Logging URL を組み立てる用に明示的に渡す。
        env {
          name  = "GOOGLE_CLOUD_PROJECT"
          value = var.project_id
        }

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
    google_secret_manager_secret_iam_member.nightly_reviewer_accessor,
    google_secret_manager_secret_iam_member.shared_slack_webhook_accessor,
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
