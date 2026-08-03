variable "project_id" {
  description = "Google Cloud プロジェクト ID"
  type        = string
}

variable "region" {
  description = "Cloud Run サービスのリージョン"
  type        = string
}

variable "internal_calls" {
  description = "実在するサービス間呼び出しの一覧。キーは「呼び出し元→呼び出し先」の識別子で、1 本ごとに run.invoker を付与する"
  type = map(object({
    caller_service_account_email = string
    callee_service_name          = string
  }))
}

variable "gateway_cloud_run_service_name" {
  description = "gateway の Cloud Run サービス名。外部からの唯一の入口として allUsers に run.invoker を付与する対象"
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
