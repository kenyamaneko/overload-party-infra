# brand cluster 上に env nodepool (dev/stg/prod) を declare する。

data "google_container_cluster" "host" {
  project  = var.cluster_host_project
  name     = var.cluster_name
  location = var.cluster_location
}

resource "google_container_node_pool" "pools_tracked" {
  for_each = { for k, v in var.node_pools : k => v if !v.ignore_node_count }

  name     = "${var.cluster_name}-${each.key}"
  project  = var.cluster_host_project
  location = var.cluster_location
  cluster  = data.google_container_cluster.host.name

  node_count = each.value.node_count

  node_config {
    machine_type = each.value.machine_type
    labels       = each.value.labels

    dynamic "taint" {
      for_each = each.value.taints
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}

resource "google_container_node_pool" "pools_ignored" {
  for_each = { for k, v in var.node_pools : k => v if v.ignore_node_count }

  name     = "${var.cluster_name}-${each.key}"
  project  = var.cluster_host_project
  location = var.cluster_location
  cluster  = data.google_container_cluster.host.name

  node_count = each.value.node_count

  node_config {
    machine_type = each.value.machine_type
    labels       = each.value.labels

    dynamic "taint" {
      for_each = each.value.taints
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  lifecycle {
    ignore_changes = [node_count]
  }
}
