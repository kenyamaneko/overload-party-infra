# スター型トポロジ (gateway → 各サービス) のため付与は線形。battle も対象に含む。
# サービス間の同期呼び出し (battle→card, card→account) は HTTP 経由で各サービスの runtime SA を
# 使わないため、invoker 対象は gateway に限定する (card→account, battle→card は同一トラストゾーン内の
# 直接呼び出しのため IAM 保護の対象外)。

resource "google_cloud_run_v2_service_iam_member" "gateway_invoker" {
  for_each = var.cloud_run_service_names

  project  = var.project_id
  location = var.region
  name     = each.value
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.gateway_service_account_email}"
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
