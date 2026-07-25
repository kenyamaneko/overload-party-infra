output "uri" {
  description = "gateway Cloud Run サービスの URL。Cloudflare からの向き先に使用"
  value       = google_cloud_run_v2_service.gateway.uri
}
