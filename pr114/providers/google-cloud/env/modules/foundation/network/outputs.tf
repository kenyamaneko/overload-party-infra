output "network_self_link" {
  value = google_compute_network.main.self_link
}

output "network_name" {
  value = google_compute_network.main.name
}

output "subnetwork_name" {
  value = google_compute_subnetwork.main.name
}

output "service_networking_connection" {
  description = "Service networking connection (use in depends_on)"
  value       = google_service_networking_connection.private
}
