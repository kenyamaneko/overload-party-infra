variable "project_id" {
  description = "Google Cloud プロジェクト ID"
  type        = string
}

variable "region" {
  description = "Cloud Run サービスのリージョン"
  type        = string
}

variable "cloud_run_service_names" {
  description = "run.invoker を gateway に付与する対象 Cloud Run サービス名のマップ。キーはサービス識別子"
  type        = map(string)
}

variable "gateway_service_account_email" {
  description = "gateway の runtime GSA email。各 Cloud Run サービスへの run.invoker 付与対象"
  type        = string
}

variable "ci_deploy_sa_member" {
  description = "Cloud Run サービスの image 更新を行う CI デプロイ SA の IAM member 文字列"
  type        = string
}

variable "cloud_run_runtime_service_account_names" {
  description = "CI デプロイ SA に iam.serviceAccountUser を付与する Cloud Run 各サービスの runtime SA 名 (google_service_account.name 形式) のマップ"
  type        = map(string)
}

variable "gateway_deploy_sa_member" {
  description = "gateway の instance template 作成 + MIG ローリング更新を行うデプロイ SA の IAM member 文字列"
  type        = string
}

variable "gateway_runtime_service_account_name" {
  description = "gateway デプロイ SA に iam.serviceAccountUser を付与する対象。gateway runtime GSA の google_service_account.name 形式"
  type        = string
}
