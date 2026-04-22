variable "project_id" {
  description = "Google Cloud プロジェクト ID（keyandnotes-platform）"
  type        = string
}

variable "github_owner" {
  description = "GitHub オーガニゼーション名またはユーザー名"
  type        = string
}

variable "terraform_authorized_repos" {
  description = "Terraform Deployer SA を impersonate して terraform apply を流せる GitHub リポジトリ一覧"
  type        = list(string)
}

variable "analytics_deploy_projects" {
  description = "analytics リポの Cloud Functions デプロイ先プロジェクト一覧。CI SA に cloudfunctions.developer / cloudbuild.builds.editor / iam.serviceAccountUser を付与"
  type        = list(string)
}

variable "cloudrun_job_deploy_projects" {
  description = "Cloud Run Jobs (newsfeed / ops 系) のデプロイ先プロジェクト一覧。CI SA に run.developer / iam.serviceAccountUser を付与"
  type        = list(string)
}

variable "terraform_managed_projects" {
  description = "Terraform で管理するプロジェクト一覧。Terraform Deployer SA に editor + pubsub.admin + secretmanager.admin を付与"
  type        = list(string)
}

variable "cloudsql_lifecycle_projects" {
  description = "Cloud SQL の start/stop ライフサイクル操作 (nightly-shutdown / activation workflow) を行うプロジェクト一覧。prod は常時稼働のため含めない"
  type        = list(string)
}

variable "deploy_authorized_repos" {
  description = "github-deploy SA (GKE kubectl apply 用) を impersonate できる GitHub リポジトリ一覧"
  type        = list(string)
}

variable "cloudsql_operator_authorized_repos" {
  description = "gh-cloudsql-operator SA (cloudsql-activation workflow 用) を impersonate できる GitHub リポジトリ一覧"
  type        = list(string)
}
