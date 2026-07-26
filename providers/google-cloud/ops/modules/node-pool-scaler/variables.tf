variable "ops_project_id" {
  description = "本 SA を作成するプロジェクト (overload-party-ops)"
  type        = string
}

variable "github_owner" {
  description = "Workflow を実行する GitHub の owner (user / org)"
  type        = string
}

variable "github_repository" {
  description = "node-pool-scale workflow が配置されるリポジトリ名 (owner 部分を含まない)"
  type        = string
}

variable "workload_identity_pool_names" {
  description = "なりすましを許可する WIF プールの full resource name (例: projects/<num>/locations/global/workloadIdentityPools/github-actions) 一覧"
  type        = list(string)
}
