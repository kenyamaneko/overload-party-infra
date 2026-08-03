output "redis_url" {
  description = "gateway の UPSTASH_REDIS_URL に投入する接続 URL"
  value       = "rediss://default:${upstash_redis_database.this.password}@${upstash_redis_database.this.endpoint}:${upstash_redis_database.this.port}"
  sensitive   = true
}
