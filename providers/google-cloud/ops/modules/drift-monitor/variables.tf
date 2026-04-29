variable "ops_project_id" {
  description = "overload-party-ops プロジェクト ID。drift-monitor が infra リポの plan を走らせる際に必要な firebase 系 API をここで enable する"
  type        = string
}

variable "deploy_sa_member" {
  description = "drift-monitor が GitHub Actions 上で使う SA の IAM member 文字列 (監視対象プロジェクトへの viewer 系ロール付与対象)"
  type        = string
}

variable "monitored_projects" {
  description = "terraform plan を実行して drift を検知する対象プロジェクト ID のリスト"
  type        = list(string)
}

