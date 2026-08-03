variable "project_id" {
  description = "Google Cloud プロジェクト ID"
  type        = string
}

variable "job_name" {
  description = "監視対象の Cloud Run ジョブ名"
  type        = string
}

variable "notification_channel_ids" {
  description = "発報先の通知チャンネル ID の一覧"
  type        = list(string)
}

variable "failed_task_attempt_count_threshold" {
  description = "集計期間内に許容する失敗したタスク試行の件数。これを超えたら発報する"
  type        = number
}
