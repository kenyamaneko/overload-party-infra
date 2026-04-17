variable "project_id" {
  description = "Google Cloud プロジェクト ID（keyandnotes-platform）"
  type        = string
}

variable "github_owner" {
  description = "GitHub オーガニゼーション名またはユーザー名"
  type        = string
}

variable "terraform_wif_repositories" {
  description = "Terraform Deployer サービスアカウントとして認証を許可するリポジトリ一覧"
  type        = list(string)
}

variable "cloudfunctions_projects" {
  description = "CI SA に Cloud Functions デプロイ権限を付与するプロジェクト一覧"
  type        = list(string)
}

variable "cloudrun_projects" {
  description = "CI SA に Cloud Run Jobs 更新権限を付与するプロジェクト一覧"
  type        = list(string)
}

variable "terraform_editor_projects" {
  description = "Terraform Deployer SA に editor 権限を付与するプロジェクト一覧"
  type        = list(string)
}

variable "cloudsql_admin_projects" {
  description = "CI SA に Cloud SQL admin 権限を付与するプロジェクト一覧（start/stop 用）"
  type        = list(string)
}

variable "deploy_wif_repositories" {
  description = "Deploy サービスアカウント（GKE kubectl apply 用）として認証を許可するリポジトリ一覧"
  type        = list(string)
}

variable "cloudsql_operator_wif_repositories" {
  description = "Cloud SQL activation 操作用 SA として認証を許可するリポジトリ一覧（cloudsql-activation workflow 用）"
  type        = list(string)
}
