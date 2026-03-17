# ---- Workload Identity Federation ----

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

# ---- CI Service Account (イメージビルド・AR push・Cloud Functions deploy) ----

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

# Cloud Functions deploy 権限（analytics 用）
resource "google_project_iam_member" "ci_cloudfunctions_developer" {
  for_each = toset(var.cloudfunctions_projects)
  project  = each.value
  role     = "roles/cloudfunctions.developer"
  member   = "serviceAccount:${google_service_account.ci.email}"
}

# Cloud Functions deploy には Cloud Build 権限も必要
resource "google_project_iam_member" "ci_cloudbuild_editor" {
  for_each = toset(var.cloudfunctions_projects)
  project  = each.value
  role     = "roles/cloudbuild.builds.editor"
  member   = "serviceAccount:${google_service_account.ci.email}"
}

# Cloud Functions の SA を使用する権限
resource "google_project_iam_member" "ci_service_account_user" {
  for_each = toset(var.cloudfunctions_projects)
  project  = each.value
  role     = "roles/iam.serviceAccountUser"
  member   = "serviceAccount:${google_service_account.ci.email}"
}

# Cloud Run Jobs update 権限（ops: db-migrate 等, newsfeed: newsfeed-job）
resource "google_project_iam_member" "ci_run_developer" {
  for_each = toset(var.cloudrun_projects)
  project  = each.value
  role     = "roles/run.developer"
  member   = "serviceAccount:${google_service_account.ci.email}"
}

# Cloud Run Jobs update 時にジョブの SA として動作する権限（ops: db-migrate 等, newsfeed: newsfeed-job）
resource "google_project_iam_member" "ci_run_service_account_user" {
  for_each = toset(var.cloudrun_projects)
  project  = each.value
  role     = "roles/iam.serviceAccountUser"
  member   = "serviceAccount:${google_service_account.ci.email}"
}

# ---- Terraform Deployer Service Account ----

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
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.terraform.email}"
}
