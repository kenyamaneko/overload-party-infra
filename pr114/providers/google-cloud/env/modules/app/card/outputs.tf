output "uri" {
  description = "card Cloud Run サービスの URL。battle / gateway からの参照に使用"
  value       = google_cloud_run_v2_service.card.uri
}

output "service_name" {
  description = "card Cloud Run サービスの名前。IAM 付与の依存を Terraform に組ませるため、リテラルではなくこの出力を参照する"
  value       = google_cloud_run_v2_service.card.name
}
