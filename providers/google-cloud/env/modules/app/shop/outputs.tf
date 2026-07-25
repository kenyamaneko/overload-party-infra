output "uri" {
  description = "shop Cloud Run サービスの URL。gateway からの参照に使用"
  value       = google_cloud_run_v2_service.shop.uri
}
