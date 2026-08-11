output "push_service_account_email" {
  description = "push 購読の OIDC 署名に使うサービスアカウントのメールアドレス"
  value       = google_service_account.push.email
}

output "news_article_collected_topic" {
  description = "newsfeed が記事を配信するトピック名。配信側にリテラルを持たせないため出力を経由して渡す"
  value       = google_pubsub_topic.main["news_article_collected"].name
}

output "push_audience" {
  description = "gateway 向け push 購読の OIDC トークンの audience。gateway 側の検証に使う"
  value       = local.push_audiences["gateway"]
}

output "shop_push_audience" {
  description = "shop 向け push 購読の OIDC トークンの audience。shop 側の検証に使う"
  value       = local.push_audiences["shop"]
}
