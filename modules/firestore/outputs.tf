output "database_name" {
  value = google_firestore_database.default.name
}

output "location_id" {
  value = google_firestore_database.default.location_id
}
