output "uri" {
  description = "scenario Cloud Run サービスの URL。gateway からの参照に使用"
  value       = google_cloud_run_v2_service.scenario.uri
}

output "service_name" {
  description = "scenario Cloud Run サービスの名前。IAM 付与の依存を Terraform に組ませるため、リテラルではなくこの出力を参照する"
  value       = google_cloud_run_v2_service.scenario.name
}
