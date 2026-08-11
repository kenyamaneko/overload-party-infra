# Upstash のリソースと認証情報は google-cloud 側の env state とライフサイクルが異なるため、
# env ごとに state を分けて独立に apply できるようにする。
terraform {
  required_version = ">= 1.5"

  required_providers {
    upstash = {
      source  = "upstash/upstash"
      version = "~> 1.5"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

provider "upstash" {
  email   = var.upstash_email
  api_key = var.upstash_api_key
}

provider "google" {
  project = "overload-party-stg"
  region  = "asia-northeast1"
}

module "matchmaking_redis" {
  source = "../modules/matchmaking"

  env            = "stg"
  primary_region = "asia-northeast1"
  eviction       = true
}

module "newsfeed_redis" {
  source = "../modules/newsfeed"

  env            = "stg"
  primary_region = "asia-northeast1"
  eviction       = true
}

module "gateway_redis" {
  source = "../modules/gateway"

  env            = "stg"
  primary_region = "asia-northeast1"
  eviction       = true
}
