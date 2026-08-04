variable "project_id" {
  description = "Google Cloud プロジェクト ID"
  type        = string
}

variable "region" {
  description = "Google Cloud リージョン"
  type        = string
}

variable "newsfeed_image" {
  description = "Newsfeed ジョブのコンテナイメージ"
  type        = string
}

variable "network" {
  description = "Direct VPC Egress 用 VPC ネットワーク名"
  type        = string
}

variable "subnetwork" {
  description = "Direct VPC Egress 用 サブネット名"
  type        = string
}

variable "bucket_name" {
  description = "記事データを保存する GCS バケット名（グローバル一意）"
  type        = string
}

variable "news_article_collected_topic" {
  description = "収集した記事を配信する Pub/Sub トピック名"
  type        = string
}

variable "deploy_sa_member" {
  description = "Cloud Run Job invoker を付与するデプロイ SA の IAM member 文字列"
  type        = string
}

variable "service_account_email" {
  description = "Newsfeed Cloud Run Job 実行用 GSA email"
  type        = string
}

variable "scheduler_paused" {
  description = "Cloud Scheduler を PAUSED 状態で作成するか。prod は false (有効)、dev/stg は true (手動 resume 前提)"
  type        = bool
}
