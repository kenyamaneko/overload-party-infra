output "instance_name" {
  description = "Cloud SQL インスタンス名。監視の宛先を実体から導くために使用"
  value       = google_sql_database_instance.main.name
}

output "private_ip_address" {
  description = "Cloud SQL インスタンスの private IP。db-migration から参照"
  value       = google_sql_database_instance.main.private_ip_address
}
