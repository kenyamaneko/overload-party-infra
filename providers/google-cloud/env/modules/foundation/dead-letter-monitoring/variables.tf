variable "project_id" {
  description = "Google Cloud プロジェクト ID"
  type        = string
}

variable "subscription_name" {
  description = "DLQ への転送を監視する購読名"
  type        = string
}

variable "notification_channel_ids" {
  description = "発報先の通知チャンネル ID の一覧"
  type        = list(string)
}

variable "dead_letter_message_count_threshold" {
  description = "集計期間内に許容する DLQ への転送件数。これを超えたら発報する"
  type        = number
}
