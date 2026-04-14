terraform {
  required_version = ">= 1.5"

  required_providers {
    upstash = {
      source  = "upstash/upstash"
      version = "~> 1.5"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

variable "upstash_email" {
  description = "Upstash アカウントのメールアドレス"
  type        = string
  sensitive   = true
}

variable "upstash_api_key" {
  description = "Upstash API key (management API 用)"
  type        = string
  sensitive   = true
}

provider "upstash" {
  email   = var.upstash_email
  api_key = var.upstash_api_key
}

provider "google" {
  project = "overload-party-prod"
  region  = "asia-northeast1"
}

module "matchmaking_redis" {
  source = "../modules/matchmaking"

  env            = "prod"
  primary_region = "asia-northeast1"
  eviction       = true
}
