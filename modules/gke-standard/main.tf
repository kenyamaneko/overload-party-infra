locals {
  cluster_name = "keyandnotes-standard"
  region       = "asia-northeast1"
  zone         = "asia-northeast1-a"
  machine_type = "e2-standard-2"
  node_count   = 1
}

resource "google_project_service" "container" {
  project            = var.project_id
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

# 無料枠が適用されるので、単一ゾーン (zonal) クラスタを選択する。
resource "google_container_cluster" "standard" {
  depends_on = [google_project_service.container]

  name     = local.cluster_name
  location = local.zone
  project  = var.project_id

  network = var.network

  release_channel {
    channel = "REGULAR"
  }

  ip_allocation_policy {}

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  remove_default_node_pool = true
  initial_node_count       = 1

  deletion_protection = false
}

resource "google_container_node_pool" "primary" {
  name     = "${local.cluster_name}-primary"
  project  = var.project_id
  location = local.zone
  cluster  = google_container_cluster.standard.name

  node_count = local.node_count

  node_config {
    machine_type = local.machine_type

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}
