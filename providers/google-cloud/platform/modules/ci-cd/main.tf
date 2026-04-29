# SA 本体・WIF binding・付与先 = keyandnotes-platform プロジェクトの IAM は
# keyandnotes-platform リポ側で管理する。このファイルは overload-party-{dev,stg,prod,ops}
# プロジェクトへの cross-project IAM 付与のみを担う。

data "google_service_account" "ci" {
  project    = var.project_id
  account_id = "github-ci"
}

data "google_service_account" "terraform_deployer" {
  project    = var.project_id
  account_id = "terraform-deployer"
}

data "google_service_account" "cloudsql_operator" {
  project    = var.project_id
  account_id = "gh-cloudsql-operator"
}

resource "google_project_iam_member" "ci_analytics_deploy_cloudfunctions" {
  for_each = toset(var.analytics_deploy_projects)
  project  = each.value
  role     = "roles/cloudfunctions.developer"
  member   = "serviceAccount:${data.google_service_account.ci.email}"
}

resource "google_project_iam_member" "ci_analytics_deploy_cloudbuild" {
  for_each = toset(var.analytics_deploy_projects)
  project  = each.value
  role     = "roles/cloudbuild.builds.editor"
  member   = "serviceAccount:${data.google_service_account.ci.email}"
}

resource "google_project_iam_member" "ci_analytics_deploy_sa_user" {
  for_each = toset(var.analytics_deploy_projects)
  project  = each.value
  role     = "roles/iam.serviceAccountUser"
  member   = "serviceAccount:${data.google_service_account.ci.email}"
}

resource "google_project_iam_member" "ci_cloudrun_deploy" {
  for_each = toset(var.cloudrun_job_deploy_projects)
  project  = each.value
  role     = "roles/run.developer"
  member   = "serviceAccount:${data.google_service_account.ci.email}"
}

resource "google_project_iam_member" "ci_cloudrun_deploy_sa_user" {
  for_each = toset(var.cloudrun_job_deploy_projects)
  project  = each.value
  role     = "roles/iam.serviceAccountUser"
  member   = "serviceAccount:${data.google_service_account.ci.email}"
}

resource "google_project_iam_member" "ci_cloudsql_lifecycle" {
  for_each = toset(var.cloudsql_lifecycle_projects)
  project  = each.value
  role     = "roles/cloudsql.admin"
  member   = "serviceAccount:${data.google_service_account.ci.email}"
}

resource "google_project_iam_member" "terraform_editor" {
  for_each = toset(var.terraform_managed_projects)
  project  = each.value
  role     = "roles/editor"
  member   = "serviceAccount:${data.google_service_account.terraform_deployer.email}"
}

# roles/editor は pubsub の subscription/topic に対する getIamPolicy / setIamPolicy を
# 含まないため、Pub/Sub リソースの IAM binding を terraform が読み書きできない。
# これを補うため pubsub.admin を追加する。
resource "google_project_iam_member" "terraform_pubsub_admin" {
  for_each = toset(var.terraform_managed_projects)
  project  = each.value
  role     = "roles/pubsub.admin"
  member   = "serviceAccount:${data.google_service_account.terraform_deployer.email}"
}

# roles/editor は secretmanager.secrets.setIamPolicy を含まないため、Secret Manager
# リソースの IAM binding を terraform が書き込めない (pubsub と同じ制約)。
# これを補うため secretmanager.admin を追加する。
resource "google_project_iam_member" "terraform_secretmanager_admin" {
  for_each = toset(var.terraform_managed_projects)
  project  = each.value
  role     = "roles/secretmanager.admin"
  member   = "serviceAccount:${data.google_service_account.terraform_deployer.email}"
}

# activation-policy の切替は cloudsql.admin が必要。対象は cloudsql_lifecycle_projects
# と同じ (dev/stg のみ) — prod は常時稼働で start/stop 操作自体が発生しない。
resource "google_project_iam_member" "cloudsql_operator_lifecycle" {
  for_each = toset(var.cloudsql_lifecycle_projects)
  project  = each.value
  role     = "roles/cloudsql.admin"
  member   = "serviceAccount:${data.google_service_account.cloudsql_operator.email}"
}
