variable "project_id" {
  description = "Google Cloud プロジェクト ID (overload-party-ops)"
  type        = string
}

variable "region" {
  description = "Cloud Run Job を配置するリージョン"
  type        = string
}

variable "deploy_sa_member" {
  description = "Cloud Run Job invoker / developer / actAs を付与するデプロイ SA の IAM member 文字列"
  type        = string
}

variable "image" {
  description = "Cloud Run Job のコンテナイメージ。CI (overload-party-ops リポ) が gcloud run jobs update で差し替えるため、Terraform 側は初回 apply のプレースホルダ用途でのみ使う"
  type        = string
}
