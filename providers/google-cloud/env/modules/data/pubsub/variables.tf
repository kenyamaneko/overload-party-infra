variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "matchmaking_service_account_email" {
  description = "Email of the matchmaking service GSA. Granted roles/pubsub.publisher on the matchmaking-events topic."
  type        = string
}

variable "gateway_service_account_email" {
  description = "Email of the gateway service GSA. Granted roles/pubsub.subscriber on the matchmaking-events-gateway subscription and on faction-selected / premium-updated gateway subscriptions."
  type        = string
}

variable "scenario_service_account_email" {
  description = "Email of the scenario service GSA. Granted roles/pubsub.publisher on the faction-selected and player-onboarded topics (initial faction selection handoff and onboarding completion)."
  type        = string
}

variable "shop_service_account_email" {
  description = "Email of the shop service GSA. Granted roles/pubsub.publisher on the faction-selected and premium-updated topics (shop purchases, subscription updates)."
  type        = string
}

variable "account_service_account_email" {
  description = "Email of the account service GSA. Granted roles/pubsub.subscriber on the faction-selected-account-sub, premium-updated-account-sub, and player-onboarded-account-sub subscriptions."
  type        = string
}

variable "card_service_account_email" {
  description = "Email of the card service GSA. Granted roles/pubsub.subscriber on the faction-selected-card-sub subscription."
  type        = string
}

variable "newsfeed_service_account_email" {
  description = "Email of the newsfeed Cloud Run Job GSA. Granted roles/pubsub.publisher on the news-article-collected topic (ADR-020)."
  type        = string
}
