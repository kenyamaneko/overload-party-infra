output "secret_id" {
  description = "内部トークン署名鍵の Secret Manager secret_id。gateway の Cloud Run env の secret_key_ref に使用"
  value       = google_secret_manager_secret.internal_auth.secret_id
}
