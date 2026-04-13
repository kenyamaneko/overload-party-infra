output "cloudsql_connection_name" {
  value = module.database.instance_connection_name
}

output "cloudsql_private_ip" {
  value = module.database.private_ip_address
}

output "database_url_iam" {
  value     = module.database.database_url_iam
  sensitive = true
}

output "game_server_sa_email" {
  value = module.database.service_account_email
}

output "migration_job_name" {
  value = var.migration_image != "" ? module.db_migration[0].job_name : null
}

output "newsfeed_job_name" {
  value = var.enable_newsfeed ? module.newsfeed[0].newsfeed_job_name : null
}

output "newsfeed_gcs_bucket" {
  value = var.enable_newsfeed ? module.newsfeed[0].gcs_bucket_name : null
}

output "newsfeed_sa_email" {
  value = var.enable_newsfeed ? google_service_account.newsfeed[0].email : null
}

output "assets_bucket_name" {
  value = module.assets.assets_bucket_name
}

output "assets_bucket_url" {
  value = module.assets.assets_bucket_url
}

output "scenarios_bucket_name" {
  value = module.assets.scenarios_bucket_name
}

output "scenarios_bucket_url" {
  value = module.assets.scenarios_bucket_url
}

output "cloudsql_psc_service_attachment" {
  value = module.database.psc_service_attachment_link
}

output "cloudsql_dns_name" {
  value = module.database.dns_name
}

output "matchmaking_events_topic" {
  value = module.pubsub.topic_name
}

output "matchmaking_events_subscription" {
  value = module.pubsub.subscription_name
}
