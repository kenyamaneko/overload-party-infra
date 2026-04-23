variable "project_id" {
  description = "Google Cloud プロジェクト ID (overload-party-ops)"
  type        = string
}

variable "region" {
  description = "Cloud Run Service を配置するリージョン"
  type        = string
}

variable "image" {
  description = "Cloud Run Service のコンテナイメージ。CI が deploy 時に差し替えるため Terraform 側は初回 apply 用のプレースホルダ用途でのみ使う"
  type        = string
}

variable "cloudsql_admin_projects" {
  description = "slack-commands SA に roles/cloudsql.admin を付与する GCP プロジェクト ID のリスト (/db-start /db-stop が叩く対象)"
  type        = list(string)
}

variable "repos" {
  description = "/open-issues が横断検索する GitHub リポジトリ名リスト (REPOS_JSON として Cloud Run に注入)"
  type        = list(string)
}

variable "shared_slack_webhook_secret_id" {
  description = "shared module が所有する slack-webhook-url Secret の ID。slack-commands SA に accessor を付与するためこの module で参照する (現状 Cloud Run env には注入していないが、将来の Slack 通知拡張に備え accessor は維持する)"
  type        = string
}
