output "push_service_account_email" {
  description = "push subscription の OIDC 署名に使う SA の email"
  value       = google_service_account.push.email
}
