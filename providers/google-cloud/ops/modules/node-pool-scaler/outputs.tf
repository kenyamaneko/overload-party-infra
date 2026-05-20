output "service_account_email" {
  description = "node-pool-scale workflow が impersonate する GSA の email"
  value       = google_service_account.node_pool_scaler.email
}
