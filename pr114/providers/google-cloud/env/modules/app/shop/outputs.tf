output "uri" {
  description = "shop Cloud Run サービスの URL。gateway からの参照に使用"
  value       = google_cloud_run_v2_service.shop.uri
}

output "service_name" {
  description = "shop Cloud Run サービスの名前。IAM 付与の依存を Terraform に組ませるため、リテラルではなくこの出力を参照する"
  value       = google_cloud_run_v2_service.shop.name
}
