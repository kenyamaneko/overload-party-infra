output "slack_bot_token_secret_id" {
  description = "support-slack-bot-token の Secret Manager secret_id"
  value       = google_secret_manager_secret.support_secrets["support-slack-bot-token"].secret_id
}

output "sendgrid_api_key_secret_id" {
  description = "support-sendgrid-api-key の Secret Manager secret_id"
  value       = google_secret_manager_secret.support_secrets["support-sendgrid-api-key"].secret_id
}
