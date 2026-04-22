# WIF pool / github-ci SA / Artifact Registry 本体は keyandnotes-platform リポで所有する。
# このモジュールは overload-party スコープの CI/CD SA (terraform-deployer / github-deploy /
# cloudsql-operator) と、github-ci への overload-party-{dev,stg,ops} プロジェクト横断の
# IAM 付与だけを担当する。

data "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "github-actions"
}

data "google_service_account" "ci" {
  project    = var.project_id
  account_id = "github-ci"
}

# ---- github-ci への cross-project IAM（overload-party プロジェクト群への権限） ----

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

# ---- Terraform デプロイ用サービスアカウント ----

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

# ---- デプロイ用サービスアカウント (GKE kubectl apply) ----

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

resource "google_project_iam_member" "deploy_psc_forwarding_rule_manage" {
  count   = length(var.deploy_authorized_repos) > 0 ? 1 : 0
  project = var.project_id
  role    = "roles/compute.networkAdmin"
  member  = "serviceAccount:${google_service_account.deploy[0].email}"
}

# ---- Cloud SQL Operator サービスアカウント (cloudsql-activation workflow 用) ----
# ADR「ノードプールスケーリング戦略とGKEの所有権」の延長で、Cloud SQL の
# 起動/停止も overload-party-infra (DB オーナー) が担当する。
# ops の nightly-shutdown や Slack コマンドから workflow_dispatch で呼ばれる。

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

# ---- state migration: resource rename (purpose-focused naming) ----

moved {
  from = google_project_iam_member.ci_cloudfunctions_developer
  to   = google_project_iam_member.ci_analytics_deploy_cloudfunctions
}

moved {
  from = google_project_iam_member.ci_cloudbuild_editor
  to   = google_project_iam_member.ci_analytics_deploy_cloudbuild
}

moved {
  from = google_project_iam_member.ci_service_account_user
  to   = google_project_iam_member.ci_analytics_deploy_sa_user
}

moved {
  from = google_project_iam_member.ci_run_developer
  to   = google_project_iam_member.ci_cloudrun_deploy
}

moved {
  from = google_project_iam_member.ci_run_service_account_user
  to   = google_project_iam_member.ci_cloudrun_deploy_sa_user
}

moved {
  from = google_project_iam_member.ci_cloudsql_admin
  to   = google_project_iam_member.ci_cloudsql_lifecycle
}

moved {
  from = google_project_iam_member.deploy_container_developer
  to   = google_project_iam_member.deploy_gke_kubectl_apply
}

moved {
  from = google_project_iam_member.deploy_compute_network_admin
  to   = google_project_iam_member.deploy_psc_forwarding_rule_manage
}

moved {
  from = google_project_iam_member.cloudsql_operator_admin
  to   = google_project_iam_member.cloudsql_operator_lifecycle
}
