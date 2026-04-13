resource "google_project_service" "container" {
  project            = var.project_id
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

resource "google_container_cluster" "autopilot" {
  depends_on = [google_project_service.container]

  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  enable_autopilot = true

  network = var.network

  release_channel {
    channel = "REGULAR"
  }

  ip_allocation_policy {}

  deletion_protection = false
}
