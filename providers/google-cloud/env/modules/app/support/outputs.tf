output "uri" {
  description = "support Cloud Run サービスの URL。gateway からの参照に使用"
  value       = google_cloud_run_v2_service.support.uri
}
