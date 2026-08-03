terraform {
  backend "gcs" {
    bucket = "keyandnotes-tf-state"
    prefix = "overload-party/upstash/stg"
  }
}
