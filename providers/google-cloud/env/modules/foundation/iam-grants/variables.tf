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

variable "gateway_cloud_run_service_name" {
  description = "gateway の Cloud Run サービス名。外部からの唯一の入口として allUsers に run.invoker を付与する対象"
  type        = string
}

variable "battle_service_account_email" {
  description = "battle の runtime GSA email。起動時に card を呼ぶため card への run.invoker 付与対象"
  type        = string
}

variable "card_cloud_run_service_name" {
  description = "card の Cloud Run サービス名。battle からの呼び出しを受ける対象"
  type        = string
}

variable "push_service_account_email" {
  description = "Pub/Sub push subscription の OIDC 署名に使う SA の email。push_target_cloud_run_service_names への run.invoker 付与対象"
  type        = string
}

variable "push_target_cloud_run_service_names" {
  description = "push 用 SA に run.invoker を付与する Cloud Run サービス名のマップ (push 配信先のみ)。キーはサービス識別子"
  type        = map(string)
}

variable "ci_deploy_sa_member" {
  description = "Cloud Run サービスの image 更新を行う CI デプロイ SA の IAM member 文字列"
  type        = string
}

variable "cloud_run_runtime_service_account_names" {
  description = "CI デプロイ SA に iam.serviceAccountUser を付与する Cloud Run 各サービスの runtime SA 名 (google_service_account.name 形式) のマップ"
  type        = map(string)
}
