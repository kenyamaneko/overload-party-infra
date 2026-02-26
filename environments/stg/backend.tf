terraform {
  backend "gcs" {
    bucket = "overload-party-tf-state"
    prefix = "terraform/stg"
  }
}
