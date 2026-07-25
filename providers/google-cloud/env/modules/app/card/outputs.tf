output "uri" {
  description = "card Cloud Run サービスの URL。battle / gateway からの参照に使用"
  value       = google_cloud_run_v2_service.card.uri
}
