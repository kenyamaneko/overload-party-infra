output "push_service_account_email" {
  description = "push 購読の OIDC 署名に使うサービスアカウントのメールアドレス"
  value       = google_service_account.push.email
}

output "push_audience" {
  description = "gateway 向け push 購読の OIDC トークンの audience。gateway 側の検証に使う"
  value       = local.push_audiences["gateway"]
}
