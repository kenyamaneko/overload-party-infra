variable "env" {
  description = "環境識別子 (dev / stg / prod)。プロジェクト ID / DB 名 / GSA email の導出に使う"
  type        = string
}

variable "primary_region" {
  description = "Upstash Global DB の primary region (例: asia-northeast1)。現在 Upstash は全 DB を Global アーキテクチャで作成する"
  type        = string
}

variable "eviction" {
  description = "Upstash Redis の eviction を有効にするか"
  type        = bool
}
