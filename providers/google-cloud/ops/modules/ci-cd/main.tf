# SA を保持するプロジェクトでは、SA を quota project として API 呼び出しを行う際に
# IAM API と Cloud Resource Manager API が enabled である必要がある。
resource "google_project_service" "iam" {
  project            = var.project_id
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloudresourcemanager" {
  project            = var.project_id
  service            = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_service_account" "ci" {
  project      = var.project_id
  account_id   = "github-ci"
  display_name = "GitHub Actions CI"

  depends_on = [google_project_service.iam]
}

resource "google_service_account_iam_member" "ci_wif" {
  for_each           = toset(var.ci_wif_repositories)
  service_account_id = google_service_account.ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${var.workload_identity_pool_name}/attribute.repository/${var.github_owner}/${each.value}"
}

resource "google_service_account" "terraform_deployer" {
  project      = var.project_id
  account_id   = "terraform-deployer"
  display_name = "Terraform Deployer"
}

resource "google_service_account_iam_member" "terraform_deployer_wif" {
  for_each           = toset(var.terraform_deployer_wif_repositories)
  service_account_id = google_service_account.terraform_deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${var.workload_identity_pool_name}/attribute.repository/${var.github_owner}/${each.value}"
}

resource "google_service_account" "gke_deployer" {
  project      = var.project_id
  account_id   = "github-deploy"
  display_name = "GitHub Actions Deploy (k8s)"
}

resource "google_service_account_iam_member" "gke_deployer_wif" {
  for_each           = toset(var.gke_deployer_wif_repositories)
  service_account_id = google_service_account.gke_deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${var.workload_identity_pool_name}/attribute.repository/${var.github_owner}/${each.value}"
}

resource "google_service_account" "cloudsql_operator" {
  project      = var.project_id
  account_id   = "gh-cloudsql-operator"
  display_name = "GitHub Actions Cloud SQL Operator"
}

resource "google_service_account_iam_member" "cloudsql_operator_wif" {
  for_each           = toset(var.cloudsql_operator_wif_repositories)
  service_account_id = google_service_account.cloudsql_operator.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${var.workload_identity_pool_name}/attribute.repository/${var.github_owner}/${each.value}"
}

# DB マイグレーション専用 SA。github-ci と分けるのは、汎用 CI に DB 起動停止権限
# (cloudsql.admin) が漏れ出さないようにするため。
resource "google_service_account" "db_migrator" {
  project      = var.project_id
  account_id   = "gh-db-migrator"
  display_name = "GitHub Actions DB Migrator"
}

resource "google_service_account_iam_member" "db_migrator_wif" {
  for_each           = toset(var.db_migrator_wif_repositories)
  service_account_id = google_service_account.db_migrator.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${var.workload_identity_pool_name}/attribute.repository/${var.github_owner}/${each.value}"
}

resource "google_project_iam_member" "ci_analytics_deploy_cloudfunctions" {
  for_each = toset(var.analytics_deploy_projects)
  project  = each.value
  role     = "roles/cloudfunctions.developer"
  member   = "serviceAccount:${google_service_account.ci.email}"
}

resource "google_project_iam_member" "ci_analytics_deploy_cloudbuild" {
  for_each = toset(var.analytics_deploy_projects)
  project  = each.value
  role     = "roles/cloudbuild.builds.editor"
  member   = "serviceAccount:${google_service_account.ci.email}"
}

resource "google_project_iam_member" "ci_analytics_deploy_sa_user" {
  for_each = toset(var.analytics_deploy_projects)
  project  = each.value
  role     = "roles/iam.serviceAccountUser"
  member   = "serviceAccount:${google_service_account.ci.email}"
}

resource "google_project_iam_member" "ci_cloudrun_deploy" {
  for_each = toset(var.cloudrun_job_deploy_projects)
  project  = each.value
  role     = "roles/run.developer"
  member   = "serviceAccount:${google_service_account.ci.email}"
}

resource "google_project_iam_member" "ci_cloudrun_deploy_sa_user" {
  for_each = toset(var.cloudrun_job_deploy_projects)
  project  = each.value
  role     = "roles/iam.serviceAccountUser"
  member   = "serviceAccount:${google_service_account.ci.email}"
}

resource "google_project_iam_member" "terraform_editor" {
  for_each = toset(var.terraform_managed_projects)
  project  = each.value
  role     = "roles/editor"
  member   = "serviceAccount:${google_service_account.terraform_deployer.email}"
}

# roles/editor は pubsub の subscription/topic に対する getIamPolicy / setIamPolicy を
# 含まないため、Pub/Sub リソースの IAM binding を terraform が読み書きできない。
resource "google_project_iam_member" "terraform_pubsub_admin" {
  for_each = toset(var.terraform_managed_projects)
  project  = each.value
  role     = "roles/pubsub.admin"
  member   = "serviceAccount:${google_service_account.terraform_deployer.email}"
}

# roles/editor は secretmanager.secrets.setIamPolicy を含まないため、Secret Manager
# リソースの IAM binding を terraform が書き込めない (pubsub と同じ制約)。
resource "google_project_iam_member" "terraform_secretmanager_admin" {
  for_each = toset(var.terraform_managed_projects)
  project  = each.value
  role     = "roles/secretmanager.admin"
  member   = "serviceAccount:${google_service_account.terraform_deployer.email}"
}

# google_project_iam_member 等の cross-project IAM を terraform 管理するために
# プロジェクトの setIamPolicy 権限が必要 (roles/editor には含まれない)。
resource "google_project_iam_member" "terraform_project_iam_admin" {
  for_each = toset(var.terraform_managed_projects)
  project  = each.value
  role     = "roles/resourcemanager.projectIamAdmin"
  member   = "serviceAccount:${google_service_account.terraform_deployer.email}"
}

# overload-party-ops プロジェクト内の SA (この module の 4 SA を含む) と
# その IAM (workload identity binding 等) を terraform で管理するために必要。
resource "google_project_iam_member" "terraform_service_account_admin" {
  project = var.project_id
  role    = "roles/iam.serviceAccountAdmin"
  member  = "serviceAccount:${google_service_account.terraform_deployer.email}"
}

# activation-policy の切替は cloudsql.admin が必要。
resource "google_project_iam_member" "cloudsql_operator_lifecycle" {
  for_each = toset(var.cloudsql_lifecycle_projects)
  project  = each.value
  role     = "roles/cloudsql.admin"
  member   = "serviceAccount:${google_service_account.cloudsql_operator.email}"
}

# db-migrate workflow が実行する 3 操作: 停止中 dev/stg を起動 (cloudsql.admin) +
# Cloud Run Job db-migrate の image 更新と実行 (run.developer) + Job 実行時の
# runtime SA バインド (iam.serviceAccountUser)。
resource "google_project_iam_member" "db_migrator_cloudsql_admin" {
  for_each = toset(var.db_migrator_target_projects)
  project  = each.value
  role     = "roles/cloudsql.admin"
  member   = "serviceAccount:${google_service_account.db_migrator.email}"
}

resource "google_project_iam_member" "db_migrator_run_developer" {
  for_each = toset(var.db_migrator_target_projects)
  project  = each.value
  role     = "roles/run.developer"
  member   = "serviceAccount:${google_service_account.db_migrator.email}"
}

resource "google_project_iam_member" "db_migrator_sa_user" {
  for_each = toset(var.db_migrator_target_projects)
  project  = each.value
  role     = "roles/iam.serviceAccountUser"
  member   = "serviceAccount:${google_service_account.db_migrator.email}"
}
