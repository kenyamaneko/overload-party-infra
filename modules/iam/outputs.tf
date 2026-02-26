output "service_account_email" {
  value = google_service_account.game_server.email
}

output "service_account_name" {
  value = google_service_account.game_server.name
}
