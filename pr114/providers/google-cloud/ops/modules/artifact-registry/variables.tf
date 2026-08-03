variable "project_id" {
  description = "Artifact Registry リポジトリを作成する Google Cloud プロジェクト ID"
  type        = string
}

variable "region" {
  description = "Artifact Registry リポジトリのリージョン"
  type        = string
}

variable "repository_id" {
  description = "Artifact Registry リポジトリ ID"
  type        = string
}

variable "cloudrun_consumer_project_numbers" {
  description = "この AR からイメージを pull する Cloud Run 側の { 名前 = プロジェクト番号 } マップ。Cloud Run サービスエージェントの member 名はプロジェクト番号で一意に決まる"
  type        = map(string)
}

variable "writer_members" {
  description = "この AR へイメージを push する CI SA の IAM member 文字列一覧"
  type        = list(string)
}
