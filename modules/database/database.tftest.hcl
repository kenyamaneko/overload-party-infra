mock_provider "google" {}

variables {
  project_id         = "test-project"
  region             = "asia-northeast1"
  network_id         = "projects/test-project/global/networks/test-network"
  service_account_id = "overload-party-app"
}

run "workload_identity_skipped_by_default" {
  command = plan

  assert {
    condition     = length(google_service_account_iam_member.workload_identity) == 0
    error_message = "Workload Identity binding should not be created when gke_project_id is empty"
  }
}

run "workload_identity_created_when_gke_project_set" {
  command = plan

  variables {
    gke_project_id = "keyandnotes-platform"
  }

  assert {
    condition     = length(google_service_account_iam_member.workload_identity) == 1
    error_message = "Workload Identity binding should be created when gke_project_id is set"
  }
}

run "iam_user_type_is_cloud_iam_service_account" {
  command = plan

  assert {
    condition     = google_sql_user.iam_user.type == "CLOUD_IAM_SERVICE_ACCOUNT"
    error_message = "SQL user type should be CLOUD_IAM_SERVICE_ACCOUNT"
  }
}
