output "bucket_name" {
  description = "カード / 施策マスタを保存する GCS バケット名。battle の参照先として使用"
  value       = google_storage_bucket.master_data.name
}
