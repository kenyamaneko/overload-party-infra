output "slack_webhook_url_secret_id" {
  description = "真の共有 Secret である slack-webhook-url の Secret ID。各 consumer module が自分の SA に accessor IAM を付与する際に参照する"
  value       = google_secret_manager_secret.slack_webhook_url.secret_id
}
