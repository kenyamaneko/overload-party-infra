mock_provider "google" {}

variables {
  project_id        = "test-project"
  region            = "asia-northeast1"
  cloudsql_instance = "test-db"
  stop_schedule     = "0 2 * * *"
}

run "stop_scheduler_is_created" {
  command = plan

  assert {
    condition     = google_cloud_scheduler_job.stop_cloudsql.name == "stop-cloudsql"
    error_message = "Stop scheduler job name mismatch"
  }

  assert {
    condition     = google_cloud_scheduler_job.stop_cloudsql.schedule == "0 2 * * *"
    error_message = "Stop schedule mismatch"
  }

  assert {
    condition     = google_cloud_scheduler_job.stop_cloudsql.time_zone == "Asia/Tokyo"
    error_message = "Default timezone should be Asia/Tokyo"
  }
}

run "start_scheduler_skipped_by_default" {
  command = plan

  assert {
    condition     = length(google_cloud_scheduler_job.start_cloudsql) == 0
    error_message = "Start scheduler should not be created when start_schedule is empty"
  }
}

run "start_scheduler_created_when_set" {
  command = plan

  variables {
    start_schedule = "0 9 * * 1-5"
  }

  assert {
    condition     = length(google_cloud_scheduler_job.start_cloudsql) == 1
    error_message = "Start scheduler should be created when start_schedule is set"
  }

  assert {
    condition     = google_cloud_scheduler_job.start_cloudsql[0].schedule == "0 9 * * 1-5"
    error_message = "Start schedule mismatch"
  }
}
