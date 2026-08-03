# E2E テスト時に Firebase Custom Token を発行するには、ローカルの ADC がこの SA に
# なりすまして JWT 署名を行う必要があるため、開発者に tokenCreator を付与する。

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
