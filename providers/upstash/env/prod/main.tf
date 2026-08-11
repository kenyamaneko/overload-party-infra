# Upstash は Google Cloud provider と独立しており、env ごとに state を分けて独立に apply できるようにする。
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
  project = "overload-party-prod"
  region  = "asia-northeast1"
}

# eviction = true: matchmaking:queue の実データは playerID:deckID の数十バイト×待機人数で、
# eviction が発動するほどメモリが埋まることはない。万一メモリ上限に達した場合も
# OOM エラーで書き込みを止めるより LRU で縮退する方が可用性を優先できるため true にしている。
module "matchmaking_redis" {
  source = "../modules/matchmaking"

  env            = "prod"
  primary_region = "asia-northeast1"
  eviction       = true
}

module "newsfeed_redis" {
  source = "../modules/newsfeed"

  env            = "prod"
  primary_region = "asia-northeast1"
  eviction       = true
}

# eviction = true: gateway が置くのは対戦ごとの計時の写しで、主はインメモリ側にある。
# 失われても対戦は続くため、メモリ上限に達したとき書き込みを止めるより縮退させる方がよい。
module "gateway_redis" {
  source = "../modules/gateway"

  env            = "prod"
  primary_region = "asia-northeast1"
  eviction       = true
}
