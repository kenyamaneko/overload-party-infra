output "private_ip_address" {
  description = "Cloud SQL インスタンスの private IP。newsfeed / db-migration から参照"
  value       = google_sql_database_instance.main.private_ip_address
}
