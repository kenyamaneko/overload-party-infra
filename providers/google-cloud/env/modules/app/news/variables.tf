variable "project_id" {
  description = "Google Cloud プロジェクト ID"
  type        = string
}

variable "region" {
  description = "Google Cloud リージョン"
  type        = string
}

variable "env_name" {
  description = "news の config.go が要求する ENV 値 (\"staging\" | \"production\")。dev/stg は staging、prod のみ production"
  type        = string
}

variable "image" {
  description = "news の初期コンテナイメージ (以降の実イメージは CI/CD が所有し ignore_changes 対象)"
  type        = string
}

variable "service_account_email" {
  description = "news Cloud Run 実行用 GSA email"
  type        = string
}

variable "network" {
  description = "Direct VPC Egress 用 VPC ネットワーク名"
  type        = string
}

variable "subnetwork" {
  description = "Direct VPC Egress 用サブネット名"
  type        = string
}

variable "cloudsql_connection_name" {
  description = "Cloud SQL インスタンスの接続名 (project:region:instance)"
  type        = string
}

variable "database_name" {
  description = "接続先 PostgreSQL データベース名"
  type        = string
}

variable "max_instance_count" {
  description = "Cloud Run 最大インスタンス数 (Cloud SQL コネクション枯渇防止の上限)"
  type        = number
}

variable "resources_limit_cpu" {
  description = "コンテナ CPU 上限 (k8s limits.cpu 相当)"
  type        = string
}

variable "resources_limit_memory" {
  description = "コンテナメモリ上限 (k8s limits.memory 相当)"
  type        = string
}

variable "internal_auth_secret_id" {
  description = "内部認証共有鍵 (HS256) の Secret Manager secret_id"
  type        = string
}

variable "news_article_collected_subscription" {
  description = "news-article-collected の news 向け pull subscription 名"
  type        = string
}
