locals {
  job_name = "nightly-review"

  # この module が自モジュール専用 Secret の枠を所有する。実値は手動で投入:
  #   gcloud secrets versions add nightly-review-anthropic-key --project <project_id> --data-file=- <<< "<ANTHROPIC_API_KEY>"
  #   gcloud secrets versions add github-pat-nightly-review    --project <project_id> --data-file=- <<< "<GITHUB_PAT>"
  module_owned_secret_ids = {
    anthropic_api_key = "nightly-review-anthropic-key"
    github_token      = "github-pat-nightly-review"
  }

  # slack-webhook-url は slack-commands 等と同じ webhook URL を叩く真の共有 Secret。
  # 枠 / accessor は overload-party-ops/terraform/shared で一元管理されている。実値の
  # 二重管理を避けるためそちらを参照する (accessor への nightly-reviewer SA 追加は
  # shared/terraform.tfvars 側で行う)。
  shared_slack_webhook_secret_id = "slack-webhook-url"

  env_to_secret = {
    ANTHROPIC_API_KEY = local.module_owned_secret_ids.anthropic_api_key
    GITHUB_TOKEN      = local.module_owned_secret_ids.github_token
    SLACK_WEBHOOK_URL = local.shared_slack_webhook_secret_id
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
# 自モジュール所有 Secret (枠のみ、バージョンは手動投入)
# ──────────────────────────────────────────────

resource "google_secret_manager_secret" "nightly_review" {
  for_each = local.module_owned_secret_ids

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

# 自 module 所有 Secret への accessor。プロジェクト全体に secretAccessor を広げず
# 対象シークレットだけに限定する (最小権限原則)。
# 真の共有 Secret である slack-webhook-url への accessor は、枠を持つ
# overload-party-ops/terraform/shared/terraform.tfvars の slack_webhook_url_accessors
# に nightly-reviewer SA を追加することで付与する。
resource "google_secret_manager_secret_iam_member" "nightly_reviewer_accessor" {
  for_each = local.module_owned_secret_ids

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
