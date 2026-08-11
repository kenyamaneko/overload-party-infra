# 運用ツール (drift-monitor / cost-monitor) は env を全 destroy しても残す必要があり、
# state を env のライフサイクルから独立させる。
terraform {
  backend "gcs" {
    bucket = "keyandnotes-tf-state"
    prefix = "overload-party/ops"
  }
}
