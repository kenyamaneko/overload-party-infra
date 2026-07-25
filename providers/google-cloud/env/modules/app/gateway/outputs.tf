output "static_ip_address" {
  description = "gateway の外部静的 IP (use_static_ip=false の場合は null)。DNS / Cloudflare 設定に使用"
  value       = var.use_static_ip ? google_compute_address.gateway_static[0].address : null
}
