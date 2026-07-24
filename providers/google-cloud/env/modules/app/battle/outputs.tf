output "uri" {
  description = "battle Cloud Run サービスの URL。gateway からの参照に使用"
  value       = google_cloud_run_v2_service.battle.uri
}
