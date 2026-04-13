output "topic_id" {
  description = "Fully-qualified ID of the matchmaking-events topic"
  value       = google_pubsub_topic.matchmaking_events.id
}

output "topic_name" {
  description = "Short name of the matchmaking-events topic"
  value       = google_pubsub_topic.matchmaking_events.name
}

output "subscription_id" {
  description = "Fully-qualified ID of the matchmaking-events-gateway subscription"
  value       = google_pubsub_subscription.matchmaking_events_gateway.id
}

output "subscription_name" {
  description = "Short name of the matchmaking-events-gateway subscription"
  value       = google_pubsub_subscription.matchmaking_events_gateway.name
}

output "dlq_topic_id" {
  description = "Fully-qualified ID of the DLQ topic"
  value       = google_pubsub_topic.matchmaking_events_dlq.id
}

# ==============================================================================
# サービス横断イベント (faction-selected, premium-updated)
# ==============================================================================

output "faction_selected_topic_name" {
  description = "Short name of the faction-selected topic (published by scenario + shop)"
  value       = google_pubsub_topic.faction_selected.name
}

output "faction_selected_subscription_names" {
  description = "Map of subscriber key -> subscription name for faction-selected"
  value       = { for k, v in google_pubsub_subscription.faction_selected : k => v.name }
}

output "faction_selected_dlq_topic_id" {
  description = "Fully-qualified ID of the faction-selected DLQ topic"
  value       = google_pubsub_topic.faction_selected_dlq.id
}

output "premium_updated_topic_name" {
  description = "Short name of the premium-updated topic (published by shop)"
  value       = google_pubsub_topic.premium_updated.name
}

output "premium_updated_subscription_names" {
  description = "Map of subscriber key -> subscription name for premium-updated"
  value       = { for k, v in google_pubsub_subscription.premium_updated : k => v.name }
}

output "premium_updated_dlq_topic_id" {
  description = "Fully-qualified ID of the premium-updated DLQ topic"
  value       = google_pubsub_topic.premium_updated_dlq.id
}
