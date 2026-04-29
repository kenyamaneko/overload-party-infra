variable "project_id" {
  description = "Google Cloud プロジェクト ID（keyandnotes-platform）"
  type        = string
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
