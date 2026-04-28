# SA は Firebase Admin SDK が createCustomToken の JWT 署名で impersonate する対象。
# 開発者 ADC は signBlob を SA に対して呼ぶため tokenCreator が必要。

variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "developer_members" {
  description = "tokenCreator / secretAccessor を付与する開発者 IAM member 一覧 (例: user:foo@example.com)"
  type        = list(string)
}

resource "google_project_service" "secretmanager" {
  project            = var.project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_service_account" "test_runner" {
  project      = var.project_id
  account_id   = "e2e-test-runner"
  display_name = "Overload Party E2E Test Runner"
}

resource "google_service_account_iam_member" "developer_token_creator" {
  for_each = toset(var.developer_members)

  service_account_id = google_service_account.test_runner.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = each.key
}

resource "google_secret_manager_secret" "firebase_test_api_key" {
  project   = var.project_id
  secret_id = "e2e-firebase-test-api-key"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_iam_member" "developer_accessor" {
  for_each = toset(var.developer_members)

  project   = var.project_id
  secret_id = google_secret_manager_secret.firebase_test_api_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = each.key
}
