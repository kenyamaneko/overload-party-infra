variable "ops_project_id" {
  description = "overload-party-ops プロジェクト ID。gcloud sql コマンド実行のため sqladmin API をここで enable する"
  type        = string
}

variable "deploy_sa_member" {
  description = "cost-monitor が GitHub Actions 上で使う SA の IAM member 文字列 (各監視対象プロジェクトへ viewer 系ロールを付与する対象)"
  type        = string
}

variable "monitored_projects" {
  description = "Cloud SQL / Compute の稼働状態を監視するプロジェクト ID のリスト"
  type        = list(string)
}

variable "gke_project" {
  description = "GKE の Deployment / Ingress を監視するプロジェクト ID"
  type        = string
}
