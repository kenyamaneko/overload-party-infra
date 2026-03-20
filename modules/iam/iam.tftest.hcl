mock_provider "google" {}

variables {
  project_id         = "test-project"
  service_account_id = "test-app"
  gke_project_id     = "test-platform"
  k8s_namespace      = "dev"
  k8s_service_account = "game-server"
}

run "service_account_is_created" {
  command = plan

  assert {
    condition     = google_service_account.game_server.account_id == "test-app"
    error_message = "Service account ID mismatch"
  }
}

run "workload_identity_bound_when_gke_project_set" {
  command = plan

  assert {
    condition     = length(google_service_account_iam_member.workload_identity) == 1
    error_message = "Workload Identity binding should be created when gke_project_id is set"
  }
}

run "workload_identity_skipped_when_gke_project_empty" {
  command = plan

  variables {
    gke_project_id = ""
  }

  assert {
    condition     = length(google_service_account_iam_member.workload_identity) == 0
    error_message = "Workload Identity binding should not be created when gke_project_id is empty"
  }
}

run "deploy_sa_permission_when_set" {
  command = plan

  variables {
    deploy_service_account_email = "ci@test.iam.gserviceaccount.com"
  }

  assert {
    condition     = length(google_project_iam_member.deploy_sa_cloudsql_admin) == 1
    error_message = "Deploy SA Cloud SQL admin should be created when email is set"
  }
}

run "deploy_sa_permission_skipped_when_empty" {
  command = plan

  assert {
    condition     = length(google_project_iam_member.deploy_sa_cloudsql_admin) == 0
    error_message = "Deploy SA permission should not be created when email is empty"
  }
}

run "terraform_editor_when_set" {
  command = plan

  variables {
    terraform_service_account_email = "tf@test.iam.gserviceaccount.com"
  }

  assert {
    condition     = length(google_project_iam_member.terraform_editor) == 1
    error_message = "Terraform editor should be created when email is set"
  }
}

run "terraform_editor_skipped_when_empty" {
  command = plan

  assert {
    condition     = length(google_project_iam_member.terraform_editor) == 0
    error_message = "Terraform editor should not be created when email is empty"
  }
}
