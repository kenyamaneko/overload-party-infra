variable "project_id" {
  description = "Google Cloud プロジェクト ID"
  type        = string
}

variable "region" {
  description = "GCS バケットのロケーション"
  type        = string
}

variable "assets_bucket_name" {
  description = "公開アセットバケット名（CDN CNAME 用、グローバル一意。例: overload-party-assets-dev.keyandnotes.com）"
  type        = string
}

variable "scenarios_bucket_name" {
  description = "非公開シナリオスクリプトバケット名（グローバル一意）"
  type        = string
}
