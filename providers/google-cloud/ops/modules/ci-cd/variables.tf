variable "project_id" {
  description = "Google Cloud プロジェクト ID（overload-party-ops）"
  type        = string
}

variable "github_owner" {
  description = "GitHub オーガニゼーション名またはユーザー名"
  type        = string
}

variable "workload_identity_pool_names" {
  description = "なりすましを許可する Workload Identity Pool のフル名（projects/<num>/locations/global/workloadIdentityPools/<id>）一覧"
  type        = list(string)
}

variable "ci_wif_repositories" {
  description = "github-ci SA を impersonate できる GitHub リポジトリ一覧"
  type        = list(string)
}

variable "terraform_deployer_wif_repositories" {
  description = "terraform-deployer SA を impersonate できる GitHub リポジトリ一覧"
  type        = list(string)
}

variable "gke_deployer_wif_repositories" {
  description = "github-deploy SA (k8s kubectl apply / PSC 配線用) を impersonate できる GitHub リポジトリ一覧"
  type        = list(string)
}

variable "cloudsql_operator_wif_repositories" {
  description = "gh-cloudsql-operator SA (Cloud SQL start/stop 用) を impersonate できる GitHub リポジトリ一覧"
  type        = list(string)
}

variable "db_migrator_wif_repositories" {
  description = "gh-db-migrator SA (db-migrate workflow 用) を impersonate できる GitHub リポジトリ一覧"
  type        = list(string)
}

variable "db_migrator_target_projects" {
  description = "db-migrate workflow が DB 起動・Cloud Run Job 実行を行う対象プロジェクト一覧 (prod は db-migrate workflow の対象外なので含めない)"
  type        = list(string)
}

variable "analytics_deploy_projects" {
  description = "analytics リポの Cloud Functions デプロイ先プロジェクト一覧。github-ci に cloudfunctions.developer / cloudbuild.builds.editor / iam.serviceAccountUser を付与"
  type        = list(string)
}

variable "cloudrun_job_deploy_projects" {
  description = "Cloud Run Jobs (newsfeed / ops 系) のデプロイ先プロジェクト一覧。github-ci に run.developer / iam.serviceAccountUser を付与"
  type        = list(string)
}

variable "terraform_managed_projects" {
  description = "Terraform で管理するプロジェクト一覧。terraform-deployer に editor + pubsub.admin + secretmanager.admin を付与"
  type        = list(string)
}

variable "cloudsql_lifecycle_projects" {
  description = "Cloud SQL の start/stop ライフサイクル操作 (nightly-shutdown / activation workflow) を行うプロジェクト一覧。prod は常時稼働のため含めない"
  type        = list(string)
}
