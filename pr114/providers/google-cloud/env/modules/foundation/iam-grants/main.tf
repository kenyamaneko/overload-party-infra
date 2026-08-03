# Cloud Run は allUsers 以外のあらゆる呼び出しに run.invoker を要求するため、実在する
# サービス間の呼び出し 1 本ごとに付与が要る。呼び出し関係を internal_calls に列挙し、
# 付与をそこから導くことで、呼び出しを増やしたときの付け忘れを防ぐ。
resource "google_cloud_run_v2_service_iam_member" "internal_invoker" {
  for_each = var.internal_calls

  project  = var.project_id
  location = var.region
  name     = each.value.callee_service_name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${each.value.caller_service_account_email}"
}

# gateway は外部からの唯一の入口のため、未認証呼び出しを許可する。
resource "google_cloud_run_v2_service_iam_member" "gateway_unauthenticated" {
  project  = var.project_id
  location = var.region
  name     = var.gateway_cloud_run_service_name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# push subscription の配信は push 用 SA の OIDC トークンを使った HTTP 呼び出しのため、呼び出し IAM を通すには push 先サービスへの run.invoker が要る。
resource "google_cloud_run_v2_service_iam_member" "push_invoker" {
  for_each = var.push_target_cloud_run_service_names

  project  = var.project_id
  location = var.region
  name     = each.value
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.push_service_account_email}"
}

# config は Terraform が所有し、CI は image のみ更新する。
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
