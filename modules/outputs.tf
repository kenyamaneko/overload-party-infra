output "cloudsql_psc_service_attachment" {
  value = module.database.psc_service_attachment_link
}

output "cloudsql_dns_name" {
  value = module.database.dns_name
}
