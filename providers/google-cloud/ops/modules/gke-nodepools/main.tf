# env 専用 nodepool (dev/stg/prod) の宣言。
# 物理 GCE VM は cluster_host_project (= keyandnotes-platform) に作られるが、
# 論理所有は app。本 module は brand 側 app-window の W1 grant
# (terraform-deployer に clusterAdmin) を前提に動く。
# 設計の根拠は overload-party-common ADR-045 を参照。

data "google_container_cluster" "host" {
  project  = var.cluster_host_project
  name     = var.cluster_name
  location = var.cluster_location
}

# Terraform が node_count を直接管理するプール (prod 等)。
# node_count を Actions resize で動かさないものはこちらに分類する。
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

    # Pod が KSA → GSA で認証できるようにするモード。
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}

# node-pool-scale workflow が gcloud resize で node_count を動的に変えるプール
# (dev/stg)。Terraform plan で diff 扱いされないよう ignore_changes に入れる。
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
