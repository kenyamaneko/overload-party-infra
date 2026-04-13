output "accounts" {
  description = "Map of service name -> google_service_account resource."
  value       = google_service_account.accounts
}
