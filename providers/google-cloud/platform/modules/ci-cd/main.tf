data "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "github-actions"
}

data "google_service_account" "ci" {
  project    = var.project_id
  account_id = "github-ci"
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

resource "google_service_account" "terraform" {
  project      = var.project_id
  account_id   = "terraform-deployer"
  display_name = "Terraform Deployer"
}

resource "google_service_account_iam_member" "terraform_wif" {
  for_each           = toset(var.terraform_authorized_repos)
  service_account_id = google_service_account.terraform.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${data.google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_owner}/${each.value}"
}

resource "google_project_iam_member" "terraform_editor" {
  for_each = toset(var.terraform_managed_projects)
  project  = each.value
  role     = "roles/editor"
  member   = "serviceAccount:${google_service_account.terraform.email}"
}

# roles/editor は pubsub の subscription/topic に対する getIamPolicy / setIamPolicy を
# 含まないため、Pub/Sub リソースの IAM binding を terraform が読み書きできない。
# これを補うため pubsub.admin を追加する。
resource "google_project_iam_member" "terraform_pubsub_admin" {
  for_each = toset(var.terraform_managed_projects)
  project  = each.value
  role     = "roles/pubsub.admin"
  member   = "serviceAccount:${google_service_account.terraform.email}"
}

# roles/editor は secretmanager.secrets.setIamPolicy を含まないため、Secret Manager
# リソースの IAM binding を terraform が書き込めない (pubsub と同じ制約)。
# これを補うため secretmanager.admin を追加する。
resource "google_project_iam_member" "terraform_secretmanager_admin" {
  for_each = toset(var.terraform_managed_projects)
  project  = each.value
  role     = "roles/secretmanager.admin"
  member   = "serviceAccount:${google_service_account.terraform.email}"
}

resource "google_service_account" "deploy" {
  count        = length(var.deploy_authorized_repos) > 0 ? 1 : 0
  project      = var.project_id
  account_id   = "github-deploy"
  display_name = "GitHub Actions Deploy (k8s)"
}

resource "google_service_account_iam_member" "deploy_wif" {
  for_each           = toset(var.deploy_authorized_repos)
  service_account_id = google_service_account.deploy[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${data.google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_owner}/${each.value}"
}

resource "google_project_iam_member" "deploy_gke_kubectl_apply" {
  count   = length(var.deploy_authorized_repos) > 0 ? 1 : 0
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.deploy[0].email}"
}

# PSC forwarding rule の create/delete に IAM 権限が必要だが、PSC 専用の粒度細かい
# role が存在しないため networkAdmin で吸収する。
resource "google_project_iam_member" "deploy_psc_forwarding_rule_manage" {
  count   = length(var.deploy_authorized_repos) > 0 ? 1 : 0
  project = var.project_id
  role    = "roles/compute.networkAdmin"
  member  = "serviceAccount:${google_service_account.deploy[0].email}"
}

resource "google_service_account" "cloudsql_operator" {
  count        = length(var.cloudsql_operator_authorized_repos) > 0 ? 1 : 0
  project      = var.project_id
  account_id   = "gh-cloudsql-operator"
  display_name = "GitHub Actions Cloud SQL Operator"
}

resource "google_service_account_iam_member" "cloudsql_operator_wif" {
  for_each           = toset(var.cloudsql_operator_authorized_repos)
  service_account_id = google_service_account.cloudsql_operator[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${data.google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_owner}/${each.value}"
}

# activation-policy の切替は cloudsql.admin が必要。対象は cloudsql_lifecycle_projects
# と同じ (dev/stg のみ) — prod は常時稼働で start/stop 操作自体が発生しない。
resource "google_project_iam_member" "cloudsql_operator_lifecycle" {
  for_each = length(var.cloudsql_operator_authorized_repos) > 0 ? toset(var.cloudsql_lifecycle_projects) : toset([])
  project  = each.value
  role     = "roles/cloudsql.admin"
  member   = "serviceAccount:${google_service_account.cloudsql_operator[0].email}"
}

output "cloudsql_operator_service_account_email" {
  value = length(var.cloudsql_operator_authorized_repos) > 0 ? google_service_account.cloudsql_operator[0].email : null
}
