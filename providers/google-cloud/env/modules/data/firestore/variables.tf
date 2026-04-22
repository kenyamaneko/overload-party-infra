variable "project_id" {
  description = "Google Cloud プロジェクト ID"
  type        = string
}

variable "location_id" {
  description = "Firestore のロケーション（multi-region または region）"
  type        = string
}

variable "game_config_reader_emails" {
  description = "game_config を読み取るサービスの SA email 一覧。roles/datastore.user を付与する"
  type        = map(string)
}
