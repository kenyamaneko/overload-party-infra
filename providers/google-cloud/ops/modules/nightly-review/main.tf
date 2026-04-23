locals {
  job_name = "nightly-review"

  # Anthropic API key は nightly-review 固有のため、この module が枠まで管理する。
  # GitHub PAT / Slack webhook は overload-party-ops/terraform/shared 側で
  # プロジェクト横断の共有 Secret として管理されており (cost-monitor / drift-monitor /
  # slack-commands が同じ実値を参照する)、同じ URL / PAT を二重管理しないためそちらを
  # 参照する。命名は shared 側の既存パターン (github-pat-*, slack-webhook-url) に
  # 揃っているため、そのまま secret ID 文字列で指す。
  self_managed_secret_ids = {
    anthropic_api_key = "nightly-review-anthropic-key"
  }

  # コンテナ env 名 → 参照先 Secret ID の対応。
  # shared 側 Secret も同一プロジェクト (overload-party-ops) にあるため ID だけで引ける。
  env_to_secret = {
    ANTHROPIC_API_KEY = local.self_managed_secret_ids.anthropic_api_key
    GITHUB_TOKEN      = "github-pat-nightly-review"
    SLACK_WEBHOOK_URL = "slack-webhook-url"
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
# nightly-review 固有 Secret (Anthropic API key)
# Terraform が作るのは 枠 のみ。バージョン (実値) は手動で追加する:
#   gcloud secrets versions add nightly-review-anthropic-key --project <project_id> --data-file=- <<< "<ANTHROPIC_API_KEY>"
# github-pat-nightly-review / slack-webhook-url は overload-party-ops/terraform/shared
# で枠を定義しており、同リポの tfvars で nightly-reviewer SA を accessor に追加する。
# ──────────────────────────────────────────────

resource "google_secret_manager_secret" "nightly_review" {
  for_each = local.self_managed_secret_ids

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
# github-pat-nightly-review / slack-webhook-url の accessor は overload-party-ops/
# terraform/shared/terraform.tfvars の *_accessors リストに nightly-reviewer SA を
# 追加することで付与する (Secret 枠が shared にあるため IAM も shared 側で一元管理)。
resource "google_secret_manager_secret_iam_member" "nightly_reviewer_accessor" {
  for_each = local.self_managed_secret_ids

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
