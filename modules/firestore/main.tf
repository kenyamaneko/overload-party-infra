resource "google_project_service" "firestore" {
  project            = var.project_id
  service            = "firestore.googleapis.com"
  disable_on_destroy = false
}

resource "google_firestore_database" "default" {
  project     = var.project_id
  name        = "(default)"
  location_id = var.location_id
  type        = "FIRESTORE_NATIVE"

  depends_on = [google_project_service.firestore]
}

resource "google_project_iam_member" "datastore_user" {
  for_each = var.reader_service_account_emails

  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${each.value}"
}
