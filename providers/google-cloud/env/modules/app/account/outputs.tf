output "uri" {
  description = "account Cloud Run サービスの URL。card / gateway からの参照に使用"
  value       = google_cloud_run_v2_service.account.uri
}
