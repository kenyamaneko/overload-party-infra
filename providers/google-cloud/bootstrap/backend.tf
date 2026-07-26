terraform {
  backend "gcs" {
    bucket = "overload-party-tfstate"
    prefix = "bootstrap"
  }
}
