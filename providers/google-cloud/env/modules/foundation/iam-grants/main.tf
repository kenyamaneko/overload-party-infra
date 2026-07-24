# ──────────────────────────────────────────────
# 到達制御: Cloud Run 呼び出し IAM
# ──────────────────────────────────────────────
# スター型トポロジ (gateway → 各サービス) のため付与は線形。battle も対象に含む。
# 同期のサービス間呼び出し (battle→card, card→account) は各サービス自身の runtime SA
# ではなく HTTP 経由なので、呼び出し先の invoker 対象は gateway に限定する
# (card→account, battle→card は当面 IAM 保護の対象外 = 同一トラストゾーン内の直接呼び出しとして扱う。
# 呼び出し元を絞る場合は該当サービスの runtime SA にも invoker を追加する)。
#
# Pub/Sub の pull→push 化は別ワークストリームで未着手のため、push 購読が実在しない現時点では
# push 用 SA への invoker 付与を行わない。push_config 追加時にその
# oidc_token.service_account_email へ同様の run.invoker を付与すること。

resource "google_cloud_run_v2_service_iam_member" "gateway_invoker" {
  for_each = var.cloud_run_service_names

  project  = var.project_id
  location = var.region
  name     = each.value
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.gateway_service_account_email}"
}

# ──────────────────────────────────────────────
# CI デプロイ SA: Cloud Run へのイメージ更新権限。config は Terraform が所有し、
# CI は image のみ更新する。
# ──────────────────────────────────────────────

resource "google_project_iam_member" "ci_cloudrun_developer" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = var.ci_deploy_sa_member
}

resource "google_service_account_iam_member" "ci_cloudrun_runtime_sa_user" {
  for_each = var.cloud_run_runtime_service_account_names

  service_account_id = each.value
  role               = "roles/iam.serviceAccountUser"
  member             = var.ci_deploy_sa_member
}

# ──────────────────────────────────────────────
# gateway デプロイ SA: instance template 作成 + MIG ローリング更新権限
# ──────────────────────────────────────────────

resource "google_project_iam_member" "gateway_deploy_compute_admin" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin.v1"
  member  = var.gateway_deploy_sa_member
}

resource "google_service_account_iam_member" "gateway_deploy_runtime_sa_user" {
  service_account_id = var.gateway_runtime_service_account_name
  role               = "roles/iam.serviceAccountUser"
  member             = var.gateway_deploy_sa_member
}
