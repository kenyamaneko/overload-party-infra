output "gateway_uri" {
  description = "gateway Cloud Run サービスの URL。Cloudflare の DNS レコード向き先に使用"
  value       = module.gateway.uri
}

output "news_uri" {
  description = "news Cloud Run サービスの URL。Cloudflare の DNS レコード向き先に使用"
  value       = module.news.uri
}

output "support_uri" {
  description = "support Cloud Run サービスの URL。Cloudflare の DNS レコード向き先に使用"
  value       = module.support.uri
}
