output "cluster_name" {
  value = google_container_cluster.standard.name
}

output "endpoint" {
  value     = google_container_cluster.standard.endpoint
  sensitive = true
}

output "location" {
  value = google_container_cluster.standard.location
}

output "ca_certificate" {
  value     = google_container_cluster.standard.master_auth[0].cluster_ca_certificate
  sensitive = true
}
