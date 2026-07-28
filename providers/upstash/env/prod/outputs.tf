output "gateway_redis_url" {
  description = "gateway-upstash-redis-url シークレットへ投入する接続 URL"
  value       = module.gateway_redis.redis_url
  sensitive   = true
}
