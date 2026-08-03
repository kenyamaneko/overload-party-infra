variable "project_id" {
  description = "Google Cloud プロジェクト ID"
  type        = string
}

variable "service_name" {
  description = "監視対象の Cloud Run サービス名"
  type        = string
}

variable "notification_channel_ids" {
  description = "発報先の通知チャンネル ID の一覧"
  type        = list(string)
}

variable "server_error_count_threshold" {
  description = "集計期間内に許容する 5xx 応答の件数。これを超えたら発報する"
  type        = number
}

variable "error_log_count_threshold" {
  description = "集計期間内に許容する ERROR ログの件数。これを超えたら発報する"
  type        = number
}

variable "latency_p95_threshold_ms" {
  description = "応答時間 (95 パーセンタイル) の上限 (ミリ秒)。null を渡すと応答時間を監視しない"
  type        = number
}
