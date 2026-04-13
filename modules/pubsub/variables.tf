variable "project_id" {
  description = "GCP project ID"
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
  description = "Email of the scenario service GSA. Granted roles/pubsub.publisher on the faction-selected topic (initial faction selection handoff)."
  type        = string
}

variable "shop_service_account_email" {
  description = "Email of the shop service GSA. Granted roles/pubsub.publisher on the faction-selected and premium-updated topics (shop purchases, subscription updates)."
  type        = string
}

variable "account_service_account_email" {
  description = "Email of the account service GSA. Granted roles/pubsub.subscriber on the faction-selected-account-sub and premium-updated-account-sub subscriptions."
  type        = string
}

variable "card_service_account_email" {
  description = "Email of the card service GSA. Granted roles/pubsub.subscriber on the faction-selected-card-sub subscription."
  type        = string
}
