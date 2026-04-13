output "job_name" {
  description = "Name of the Cloud Run migration job"
  value       = google_cloud_run_v2_job.migration.name
}

output "service_account_email" {
  description = "Email of the migration service account"
  value       = google_service_account.migration.email
}
