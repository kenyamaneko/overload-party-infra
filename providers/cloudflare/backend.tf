# DNS レコードは Google Cloud とライフサイクルが異なるため state を分離する。
terraform {
  backend "gcs" {
    bucket = "keyandnotes-tf-state"
    prefix = "overload-party/cloudflare-cdn"
  }
}
