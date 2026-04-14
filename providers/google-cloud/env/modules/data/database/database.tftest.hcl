mock_provider "google" {}

variables {
  project_id         = "test-project"
  region             = "asia-northeast1"
  network_id         = "projects/test-project/global/networks/test-network"
  service_account_id = "overload-party-app"
  service_iam_users = {
    gateway  = "overload-party-gateway@test-project.iam.gserviceaccount.com"
    account  = "overload-party-account@test-project.iam.gserviceaccount.com"
    battle   = "overload-party-battle@test-project.iam.gserviceaccount.com"
    card     = "overload-party-card@test-project.iam.gserviceaccount.com"
    shop     = "overload-party-shop@test-project.iam.gserviceaccount.com"
    scenario = "overload-party-scenario@test-project.iam.gserviceaccount.com"
  }
}

run "iam_user_type_is_cloud_iam_service_account" {
  command = plan

  assert {
    condition     = google_sql_user.iam_user.type == "CLOUD_IAM_SERVICE_ACCOUNT"
    error_message = "SQL user type should be CLOUD_IAM_SERVICE_ACCOUNT"
  }
}

run "game_server_iam_user_email_matches_service_account" {
  command = plan

  assert {
    condition     = google_sql_user.iam_user.name == trimsuffix(google_service_account.game_server.email, ".gserviceaccount.com")
    error_message = "IAM DB user name must equal the game_server SA email without .gserviceaccount.com suffix"
  }
}

run "per_service_iam_users_are_cloud_iam_service_account" {
  command = plan

  assert {
    condition     = alltrue([for u in google_sql_user.service_iam_users : u.type == "CLOUD_IAM_SERVICE_ACCOUNT"])
    error_message = "All per-service IAM DB users must be CLOUD_IAM_SERVICE_ACCOUNT"
  }
}

run "per_service_iam_user_names_strip_gserviceaccount_suffix" {
  command = plan

  assert {
    condition = alltrue([
      for svc, u in google_sql_user.service_iam_users :
      u.name == trimsuffix(var.service_iam_users[svc], ".gserviceaccount.com")
    ])
    error_message = "Per-service IAM DB user names must drop the .gserviceaccount.com suffix"
  }
}
