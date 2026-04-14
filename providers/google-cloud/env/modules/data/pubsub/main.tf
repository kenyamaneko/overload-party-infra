locals {
  topic_name        = "matchmaking-events"
  dlq_topic_name    = "matchmaking-events-dlq"
  subscription_name = "matchmaking-events-gateway"
}

# ──────────────────────────────────────────────
# API 有効化
# ──────────────────────────────────────────────

resource "google_project_service" "pubsub" {
  project            = var.project_id
  service            = "pubsub.googleapis.com"
  disable_on_destroy = false
}

# ──────────────────────────────────────────────
# トピック
# ──────────────────────────────────────────────

resource "google_pubsub_topic" "matchmaking_events" {
  depends_on = [google_project_service.pubsub]

  project = var.project_id
  name    = local.topic_name
}

resource "google_pubsub_topic" "matchmaking_events_dlq" {
  depends_on = [google_project_service.pubsub]

  project = var.project_id
  name    = local.dlq_topic_name
}

# ──────────────────────────────────────────────
# サブスクリプション (gateway コンシューマー、exactly-once)
# ──────────────────────────────────────────────

resource "google_pubsub_subscription" "matchmaking_events_gateway" {
  project = var.project_id
  name    = local.subscription_name
  topic   = google_pubsub_topic.matchmaking_events.name

  enable_exactly_once_delivery = true
  ack_deadline_seconds         = 10

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.matchmaking_events_dlq.id
    max_delivery_attempts = 5
  }
}

# ──────────────────────────────────────────────
# IAM
# ──────────────────────────────────────────────

resource "google_pubsub_topic_iam_member" "matchmaking_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.matchmaking_events.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${var.matchmaking_service_account_email}"
}

resource "google_pubsub_subscription_iam_member" "gateway_subscriber" {
  project      = var.project_id
  subscription = google_pubsub_subscription.matchmaking_events_gateway.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${var.gateway_service_account_email}"
}

# DLQ 転送用: Pub/Sub サービスエージェントに publisher + subscriber を付与
data "google_project" "this" {
  project_id = var.project_id
}

resource "google_pubsub_topic_iam_member" "dlq_service_agent_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.matchmaking_events_dlq.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_pubsub_subscription_iam_member" "dlq_service_agent_subscriber" {
  project      = var.project_id
  subscription = google_pubsub_subscription.matchmaking_events_gateway.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# ==============================================================================
# サービス横断イベント (faction-selected, premium-updated)
# ==============================================================================

locals {
  faction_selected_subscribers = {
    account = "faction-selected-account-sub"
    card    = "faction-selected-card-sub"
    gateway = "faction-selected-gateway-sub"
  }
  premium_updated_subscribers = {
    account = "premium-updated-account-sub"
    gateway = "premium-updated-gateway-sub"
  }
}

# ------------------------------------------------------------------------------
# faction-selected
# ------------------------------------------------------------------------------

resource "google_pubsub_topic" "faction_selected" {
  depends_on = [google_project_service.pubsub]

  project = var.project_id
  name    = "faction-selected"
}

resource "google_pubsub_topic" "faction_selected_dlq" {
  depends_on = [google_project_service.pubsub]

  project = var.project_id
  name    = "faction-selected-dlq"
}

resource "google_pubsub_subscription" "faction_selected" {
  for_each = local.faction_selected_subscribers

  project = var.project_id
  name    = each.value
  topic   = google_pubsub_topic.faction_selected.name

  enable_exactly_once_delivery = true
  ack_deadline_seconds         = 10

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.faction_selected_dlq.id
    max_delivery_attempts = 5
  }
}

resource "google_pubsub_topic_iam_member" "faction_selected_scenario_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.faction_selected.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${var.scenario_service_account_email}"
}

resource "google_pubsub_topic_iam_member" "faction_selected_shop_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.faction_selected.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${var.shop_service_account_email}"
}

resource "google_pubsub_subscription_iam_member" "faction_selected_account" {
  project      = var.project_id
  subscription = google_pubsub_subscription.faction_selected["account"].name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${var.account_service_account_email}"
}

resource "google_pubsub_subscription_iam_member" "faction_selected_card" {
  project      = var.project_id
  subscription = google_pubsub_subscription.faction_selected["card"].name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${var.card_service_account_email}"
}

resource "google_pubsub_subscription_iam_member" "faction_selected_gateway" {
  project      = var.project_id
  subscription = google_pubsub_subscription.faction_selected["gateway"].name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${var.gateway_service_account_email}"
}

resource "google_pubsub_topic_iam_member" "faction_selected_dlq_sa_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.faction_selected_dlq.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_pubsub_subscription_iam_member" "faction_selected_dlq_sa_subscriber" {
  for_each = local.faction_selected_subscribers

  project      = var.project_id
  subscription = google_pubsub_subscription.faction_selected[each.key].name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# ------------------------------------------------------------------------------
# premium-updated
# ------------------------------------------------------------------------------

resource "google_pubsub_topic" "premium_updated" {
  depends_on = [google_project_service.pubsub]

  project = var.project_id
  name    = "premium-updated"
}

resource "google_pubsub_topic" "premium_updated_dlq" {
  depends_on = [google_project_service.pubsub]

  project = var.project_id
  name    = "premium-updated-dlq"
}

resource "google_pubsub_subscription" "premium_updated" {
  for_each = local.premium_updated_subscribers

  project = var.project_id
  name    = each.value
  topic   = google_pubsub_topic.premium_updated.name

  enable_exactly_once_delivery = true
  ack_deadline_seconds         = 10

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.premium_updated_dlq.id
    max_delivery_attempts = 5
  }
}

resource "google_pubsub_topic_iam_member" "premium_updated_shop_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.premium_updated.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${var.shop_service_account_email}"
}

resource "google_pubsub_subscription_iam_member" "premium_updated_account" {
  project      = var.project_id
  subscription = google_pubsub_subscription.premium_updated["account"].name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${var.account_service_account_email}"
}

resource "google_pubsub_subscription_iam_member" "premium_updated_gateway" {
  project      = var.project_id
  subscription = google_pubsub_subscription.premium_updated["gateway"].name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${var.gateway_service_account_email}"
}

resource "google_pubsub_topic_iam_member" "premium_updated_dlq_sa_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.premium_updated_dlq.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_pubsub_subscription_iam_member" "premium_updated_dlq_sa_subscriber" {
  for_each = local.premium_updated_subscribers

  project      = var.project_id
  subscription = google_pubsub_subscription.premium_updated[each.key].name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}
