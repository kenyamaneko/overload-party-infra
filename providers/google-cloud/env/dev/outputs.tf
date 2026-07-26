output "gateway_uri" {
  description = "gateway Cloud Run サービスの URL。Cloudflare の DNS レコード向き先に使用"
  value       = module.env.gateway_uri
}

output "news_uri" {
  description = "news Cloud Run サービスの URL。Cloudflare の DNS レコード向き先に使用"
  value       = module.env.news_uri
}

output "support_uri" {
  description = "support Cloud Run サービスの URL。Cloudflare の DNS レコード向き先に使用"
  value       = module.env.support_uri
}
