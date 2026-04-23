output "service_url" {
  description = "Cloud Run Service の URL。cloudflare-workers composition が remote state 経由で参照し Worker binding に設定する"
  value       = google_cloud_run_v2_service.slack_commands.uri
}
