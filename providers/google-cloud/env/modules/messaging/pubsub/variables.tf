variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "matchmaking_service_account_email" {
  description = "Email of the matchmaking service GSA. Granted roles/pubsub.publisher on the matchmaking-events topic."
  type        = string
}

variable "gateway_service_account_email" {
  description = "Email of the gateway service GSA. Granted roles/pubsub.subscriber on the matchmaking-events-gateway, faction-acquired-gateway-sub, and card-pack-purchased-gateway-sub subscriptions."
  type        = string
}

variable "scenario_service_account_email" {
  description = "Email of the scenario service GSA. Granted roles/pubsub.publisher on the player-onboarded topic (onboarding completion handoff to account / card / gateway)."
  type        = string
}

variable "shop_service_account_email" {
  description = "Email of the shop service GSA. Granted roles/pubsub.publisher on the faction-acquired, card-pack-purchased, and premium-updated topics."
  type        = string
}

variable "account_service_account_email" {
  description = "Email of the account service GSA. Granted roles/pubsub.subscriber on the faction-acquired-account-sub, premium-updated-account-sub, and player-onboarded-account-sub subscriptions."
  type        = string
}

variable "card_service_account_email" {
  description = "Email of the card service GSA. Granted roles/pubsub.subscriber on the card-pack-purchased-card-sub and player-onboarded-card-sub subscriptions."
  type        = string
}

variable "newsfeed_service_account_email" {
  description = "Email of the newsfeed Cloud Run Job GSA. Granted roles/pubsub.publisher on the news-article-collected topic."
  type        = string
}

variable "news_service_account_email" {
  description = "Email of the news service GSA. Granted roles/pubsub.subscriber on the news-article-collected-news-sub subscription."
  type        = string
}
