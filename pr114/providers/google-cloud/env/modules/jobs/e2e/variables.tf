variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "developer_members" {
  description = "tokenCreator を付与する開発者 IAM member 一覧 (例: user:foo@example.com)"
  type        = list(string)
}
