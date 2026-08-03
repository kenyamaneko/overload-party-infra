output "uri" {
  description = "gateway Cloud Run サービスの URL。Cloudflare からの向き先に使用"
  value       = google_cloud_run_v2_service.gateway.uri
}

output "service_name" {
  description = "gateway Cloud Run サービスの名前。IAM 付与の依存を Terraform に組ませるため、リテラルではなくこの出力を参照する"
  value       = google_cloud_run_v2_service.gateway.name
}
