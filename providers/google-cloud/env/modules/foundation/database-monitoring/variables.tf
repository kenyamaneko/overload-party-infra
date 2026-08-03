variable "project_id" {
  description = "Google Cloud プロジェクト ID"
  type        = string
}

variable "instance_name" {
  description = "監視対象の Cloud SQL インスタンス名"
  type        = string
}

variable "notification_channel_ids" {
  description = "アラートの通知先チャンネルのリソース名"
  type        = list(string)
}

variable "cpu_utilization_threshold" {
  description = "CPU 使用率の発報閾値 (0.0 - 1.0)"
  type        = number
}

variable "memory_utilization_threshold" {
  description = "メモリ使用率の発報閾値 (0.0 - 1.0)"
  type        = number
}

variable "disk_utilization_threshold" {
  description = "ディスク使用率の発報閾値 (0.0 - 1.0)"
  type        = number
}

variable "connection_count_threshold" {
  description = "同時接続数の発報閾値。マシンタイプごとの max_connections に対して余裕を残した値にする"
  type        = number
}
