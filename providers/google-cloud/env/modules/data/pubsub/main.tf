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
# サービス横断イベント (faction-purchased, premium-updated, player-onboarded)
# ==============================================================================

locals {
  faction_purchased_subscribers = {
    account = "faction-purchased-account-sub"
    card    = "faction-purchased-card-sub"
    gateway = "faction-purchased-gateway-sub"
  }
  premium_updated_subscribers = {
    account = "premium-updated-account-sub"
    gateway = "premium-updated-gateway-sub"
  }
  player_onboarded_subscribers = {
    account = "player-onboarded-account-sub"
    card    = "player-onboarded-card-sub"
    gateway = "player-onboarded-gateway-sub"
  }
}

# ------------------------------------------------------------------------------
# faction-purchased
# ------------------------------------------------------------------------------

resource "google_pubsub_topic" "faction_purchased" {
  depends_on = [google_project_service.pubsub]

  project = var.project_id
  name    = "faction-purchased"
}

resource "google_pubsub_topic" "faction_purchased_dlq" {
  depends_on = [google_project_service.pubsub]

  project = var.project_id
  name    = "faction-purchased-dlq"
}

resource "google_pubsub_subscription" "faction_purchased" {
  for_each = local.faction_purchased_subscribers

  project = var.project_id
  name    = each.value
  topic   = google_pubsub_topic.faction_purchased.name

  enable_exactly_once_delivery = true
  ack_deadline_seconds         = 10

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.faction_purchased_dlq.id
    max_delivery_attempts = 5
  }
}

resource "google_pubsub_topic_iam_member" "faction_purchased_shop_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.faction_purchased.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${var.shop_service_account_email}"
}

resource "google_pubsub_subscription_iam_member" "faction_purchased_account" {
  project      = var.project_id
  subscription = google_pubsub_subscription.faction_purchased["account"].name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${var.account_service_account_email}"
}

resource "google_pubsub_subscription_iam_member" "faction_purchased_card" {
  project      = var.project_id
  subscription = google_pubsub_subscription.faction_purchased["card"].name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${var.card_service_account_email}"
}

resource "google_pubsub_subscription_iam_member" "faction_purchased_gateway" {
  project      = var.project_id
  subscription = google_pubsub_subscription.faction_purchased["gateway"].name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${var.gateway_service_account_email}"
}

resource "google_pubsub_topic_iam_member" "faction_purchased_dlq_sa_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.faction_purchased_dlq.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_pubsub_subscription_iam_member" "faction_purchased_dlq_sa_subscriber" {
  for_each = local.faction_purchased_subscribers

  project      = var.project_id
  subscription = google_pubsub_subscription.faction_purchased[each.key].name
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

# ------------------------------------------------------------------------------
# player-onboarded (ADR-022: scenario が publish、account / card / gateway が subscribe。
# 初期 faction 選択の下流処理は player-onboarded に集約し、
# 有料 faction 購入時のみ faction-purchased を発火する)
# ------------------------------------------------------------------------------

resource "google_pubsub_topic" "player_onboarded" {
  depends_on = [google_project_service.pubsub]

  project = var.project_id
  name    = "player-onboarded"
}

resource "google_pubsub_topic" "player_onboarded_dlq" {
  depends_on = [google_project_service.pubsub]

  project = var.project_id
  name    = "player-onboarded-dlq"
}

resource "google_pubsub_subscription" "player_onboarded" {
  for_each = local.player_onboarded_subscribers

  project = var.project_id
  name    = each.value
  topic   = google_pubsub_topic.player_onboarded.name

  enable_exactly_once_delivery = true
  ack_deadline_seconds         = 10

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.player_onboarded_dlq.id
    max_delivery_attempts = 5
  }
}

resource "google_pubsub_topic_iam_member" "player_onboarded_scenario_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.player_onboarded.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${var.scenario_service_account_email}"
}

resource "google_pubsub_subscription_iam_member" "player_onboarded_account" {
  project      = var.project_id
  subscription = google_pubsub_subscription.player_onboarded["account"].name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${var.account_service_account_email}"
}

resource "google_pubsub_subscription_iam_member" "player_onboarded_card" {
  project      = var.project_id
  subscription = google_pubsub_subscription.player_onboarded["card"].name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${var.card_service_account_email}"
}

resource "google_pubsub_subscription_iam_member" "player_onboarded_gateway" {
  project      = var.project_id
  subscription = google_pubsub_subscription.player_onboarded["gateway"].name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${var.gateway_service_account_email}"
}

resource "google_pubsub_topic_iam_member" "player_onboarded_dlq_sa_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.player_onboarded_dlq.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_pubsub_subscription_iam_member" "player_onboarded_dlq_sa_subscriber" {
  for_each = local.player_onboarded_subscribers

  project      = var.project_id
  subscription = google_pubsub_subscription.player_onboarded[each.key].name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# ==============================================================================
# news-article-collected (ADR-020: newsfeed が publish、news が subscribe)
# ==============================================================================
#
# news 側のサブスクリプション (`news-article-collected-news-sub`) は news サービスの
# デプロイ時に別 PR で追加する。本 ADR 範囲ではトピック + newsfeed publisher のみ。

resource "google_pubsub_topic" "news_article_collected" {
  depends_on = [google_project_service.pubsub]

  project = var.project_id
  name    = "news-article-collected"
}

resource "google_pubsub_topic_iam_member" "news_article_collected_newsfeed_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.news_article_collected.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${var.newsfeed_service_account_email}"
}
