output "secret_id" {
  description = "internal-auth-secret の Secret Manager secret_id。各サービスの Cloud Run env の secret_key_ref に使用"
  value       = google_secret_manager_secret.internal_auth.secret_id
}
