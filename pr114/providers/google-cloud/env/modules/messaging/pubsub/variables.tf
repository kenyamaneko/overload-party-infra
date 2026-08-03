variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "matchmaking_service_account_email" {
  description = "Email of the matchmaking service GSA. Granted roles/pubsub.publisher on the matchmaking-events topic."
  type        = string
}

variable "scenario_service_account_email" {
  description = "Email of the scenario service GSA. Granted roles/pubsub.publisher on the player-onboarded topic (onboarding completion handoff to account / card)."
  type        = string
}

variable "shop_service_account_email" {
  description = "Email of the shop service GSA. Granted roles/pubsub.publisher on the faction-acquired, card-pack-purchased, and premium-updated topics."
  type        = string
}

variable "newsfeed_service_account_email" {
  description = "Email of the newsfeed Cloud Run Job GSA. Granted roles/pubsub.publisher on the news-article-collected topic."
  type        = string
}

variable "gateway_service_url" {
  description = "gateway Cloud Run サービスの URL。matchmaking-events-gateway の push エンドポイント組み立てに使用"
  type        = string
}

variable "account_service_url" {
  description = "account Cloud Run サービスの URL。account 向け push subscription のエンドポイント組み立てに使用"
  type        = string
}

variable "card_service_url" {
  description = "card Cloud Run サービスの URL。card 向け push subscription のエンドポイント組み立てに使用"
  type        = string
}

variable "news_service_url" {
  description = "news Cloud Run サービスの URL。news-article-collected-news-sub の push エンドポイント組み立てに使用"
  type        = string
}
