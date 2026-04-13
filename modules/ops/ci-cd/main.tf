# ---- Workload Identity 連携 ----

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "github-actions"
  display_name              = "GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  attribute_condition = "assertion.repository in [${join(", ", [for r in var.allowed_repositories : "'${var.github_owner}/${r}'"])}]"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# ---- CI サービスアカウント (イメージビルド・AR push・Cloud Functions deploy) ----

resource "google_service_account" "ci" {
  project      = var.project_id
  account_id   = "github-ci"
  display_name = "GitHub Actions CI"
}

resource "google_service_account_iam_member" "ci_wif" {
  for_each           = toset(var.ci_wif_repositories)
  service_account_id = google_service_account.ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_owner}/${each.value}"
}

resource "google_artifact_registry_repository_iam_member" "ci_ar_writer" {
  project    = var.project_id
  location   = var.region
  repository = var.artifact_registry_id
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.ci.email}"
}

resource "google_project_iam_member" "ci_cloudfunctions_developer" {
  for_each = toset(var.cloudfunctions_projects)
  project  = each.value
  role     = "roles/cloudfunctions.developer"
  member   = "serviceAccount:${google_service_account.ci.email}"
}

resource "google_project_iam_member" "ci_cloudbuild_editor" {
  for_each = toset(var.cloudfunctions_projects)
  project  = each.value
  role     = "roles/cloudbuild.builds.editor"
  member   = "serviceAccount:${google_service_account.ci.email}"
}

resource "google_project_iam_member" "ci_service_account_user" {
  for_each = toset(var.cloudfunctions_projects)
  project  = each.value
  role     = "roles/iam.serviceAccountUser"
  member   = "serviceAccount:${google_service_account.ci.email}"
}

resource "google_project_iam_member" "ci_run_developer" {
  for_each = toset(var.cloudrun_projects)
  project  = each.value
  role     = "roles/run.developer"
  member   = "serviceAccount:${google_service_account.ci.email}"
}

resource "google_project_iam_member" "ci_run_service_account_user" {
  for_each = toset(var.cloudrun_projects)
  project  = each.value
  role     = "roles/iam.serviceAccountUser"
  member   = "serviceAccount:${google_service_account.ci.email}"
}

# ---- Terraform デプロイ用サービスアカウント ----

resource "google_service_account" "terraform" {
  project      = var.project_id
  account_id   = "terraform-deployer"
  display_name = "Terraform Deployer"
}

resource "google_service_account_iam_member" "terraform_wif" {
  for_each           = toset(var.terraform_wif_repositories)
  service_account_id = google_service_account.terraform.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_owner}/${each.value}"
}

resource "google_project_iam_member" "terraform_editor" {
  for_each = toset(var.terraform_editor_projects)
  project  = each.value
  role     = "roles/editor"
  member   = "serviceAccount:${google_service_account.terraform.email}"
}

resource "google_project_iam_member" "ci_cloudsql_admin" {
  for_each = toset(var.cloudsql_admin_projects)
  project  = each.value
  role     = "roles/cloudsql.admin"
  member   = "serviceAccount:${google_service_account.ci.email}"
}

# ---- デプロイ用サービスアカウント (GKE kubectl apply) ----

resource "google_service_account" "deploy" {
  count        = length(var.deploy_wif_repositories) > 0 ? 1 : 0
  project      = var.project_id
  account_id   = "github-deploy"
  display_name = "GitHub Actions Deploy (k8s)"
}

resource "google_service_account_iam_member" "deploy_wif" {
  for_each           = toset(var.deploy_wif_repositories)
  service_account_id = google_service_account.deploy[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_owner}/${each.value}"
}

resource "google_project_iam_member" "deploy_container_developer" {
  count   = length(var.deploy_wif_repositories) > 0 ? 1 : 0
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.deploy[0].email}"
}

# PSC forwarding rule の作成/削除に必要（env-lifecycle workflow）
resource "google_project_iam_member" "deploy_compute_network_admin" {
  count   = length(var.deploy_wif_repositories) > 0 ? 1 : 0
  project = var.project_id
  role    = "roles/compute.networkAdmin"
  member  = "serviceAccount:${google_service_account.deploy[0].email}"
}
