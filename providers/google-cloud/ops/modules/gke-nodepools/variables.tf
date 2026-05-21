variable "cluster_host_project" {
  description = "GKE クラスタが属する Google Cloud プロジェクト ID (brand 側 keyandnotes-platform)"
  type        = string
}

variable "cluster_name" {
  description = "対象 GKE クラスタの名前 (例: keyandnotes-main)。data source 参照と nodepool 名 prefix の両方に使う"
  type        = string
}

variable "cluster_location" {
  description = "対象 GKE クラスタのゾーン名 (例: asia-northeast1-a)"
  type        = string
}

variable "node_pools" {
  description = <<-EOT
    env nodepool 定義のマップ。キーが env 名 (dev / stg / prod) で、生成される nodepool 名は `{cluster_name}-{env}`。
    ignore_node_count = true にすると node_count を node-pool-scale workflow で動的に変えても drift 扱いされない。
    常時起動を Terraform で強制したいプールは false にする。
  EOT
  type = map(object({
    machine_type      = string
    node_count        = number
    ignore_node_count = bool
    labels            = map(string)
    taints = list(object({
      key    = string
      value  = string
      effect = string
    }))
  }))
}
