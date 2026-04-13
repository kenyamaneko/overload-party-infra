variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "location_id" {
  description = "Firestore location (multi-region or region). asia-northeast1 = Tokyo single-region."
  type        = string
  default     = "asia-northeast1"
}

variable "reader_service_account_emails" {
  description = "game_config を読み取るサービスの SA email 一覧。roles/datastore.user を付与する。"
  type        = map(string)
  default     = {}
}
