locals {
  # 各トピックの publisher / subscribers をまとめたマップ。
  # 新規トピック追加時はこのマップに 1 エントリ足すだけで topic / DLQ /
  # subscriptions / IAM 一式が生成される。
  topics = {
    matchmaking_events = {
      topic_name   = "matchmaking-events"
      publisher_sa = var.matchmaking_service_account_email
      subscribers = {
        gateway = { sub_name = "matchmaking-events-gateway", sa_email = var.gateway_service_account_email }
      }
    }
    faction_purchased = {
      topic_name   = "faction-purchased"
      publisher_sa = var.shop_service_account_email
      subscribers = {
        account = { sub_name = "faction-purchased-account-sub", sa_email = var.account_service_account_email }
        card    = { sub_name = "faction-purchased-card-sub", sa_email = var.card_service_account_email }
        gateway = { sub_name = "faction-purchased-gateway-sub", sa_email = var.gateway_service_account_email }
      }
    }
    premium_updated = {
      topic_name   = "premium-updated"
      publisher_sa = var.shop_service_account_email
      subscribers = {
        account = { sub_name = "premium-updated-account-sub", sa_email = var.account_service_account_email }
        gateway = { sub_name = "premium-updated-gateway-sub", sa_email = var.gateway_service_account_email }
      }
    }
    player_onboarded = {
      topic_name   = "player-onboarded"
      publisher_sa = var.scenario_service_account_email
      subscribers = {
        account = { sub_name = "player-onboarded-account-sub", sa_email = var.account_service_account_email }
        card    = { sub_name = "player-onboarded-card-sub", sa_email = var.card_service_account_email }
        gateway = { sub_name = "player-onboarded-gateway-sub", sa_email = var.gateway_service_account_email }
      }
    }
    news_article_collected = {
      topic_name   = "news-article-collected"
      publisher_sa = var.newsfeed_service_account_email
      subscribers = {
        news = { sub_name = "news-article-collected-news-sub", sa_email = var.news_service_account_email }
      }
    }
  }

  # subscription 単位の for_each 用フラットマップ。キーは "<topic>.<sub>" で
  # 一意化し、subscription / subscriber IAM / DLQ SA subscriber IAM から参照する。
  subscriptions = merge([
    for topic_key, topic in local.topics : {
      for sub_key, sub in topic.subscribers :
      "${topic_key}.${sub_key}" => {
        topic_key = topic_key
        sub_name  = sub.sub_name
        sa_email  = sub.sa_email
      }
    }
  ]...)
}

# ──────────────────────────────────────────────
# API 有効化
# ──────────────────────────────────────────────

resource "google_project_service" "pubsub" {
  project            = var.project_id
  service            = "pubsub.googleapis.com"
  disable_on_destroy = false
}

data "google_project" "this" {
  project_id = var.project_id
}

# ──────────────────────────────────────────────
# トピック (main / DLQ)
# ──────────────────────────────────────────────

resource "google_pubsub_topic" "main" {
  for_each = local.topics

  depends_on = [google_project_service.pubsub]

  project = var.project_id
  name    = each.value.topic_name
}

resource "google_pubsub_topic" "dlq" {
  for_each = local.topics

  depends_on = [google_project_service.pubsub]

  project = var.project_id
  name    = "${each.value.topic_name}-dlq"
}

# ──────────────────────────────────────────────
# サブスクリプション (exactly-once、DLQ 配送付き)
# ──────────────────────────────────────────────

resource "google_pubsub_subscription" "main" {
  for_each = local.subscriptions

  project = var.project_id
  name    = each.value.sub_name
  topic   = google_pubsub_topic.main[each.value.topic_key].name

  enable_exactly_once_delivery = true
  ack_deadline_seconds         = 10

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dlq[each.value.topic_key].id
    max_delivery_attempts = 5
  }
}

# ──────────────────────────────────────────────
# IAM (publisher / subscriber / DLQ サービスエージェント)
# ──────────────────────────────────────────────

resource "google_pubsub_topic_iam_member" "publisher" {
  for_each = local.topics

  project = var.project_id
  topic   = google_pubsub_topic.main[each.key].name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${each.value.publisher_sa}"
}

resource "google_pubsub_subscription_iam_member" "subscriber" {
  for_each = local.subscriptions

  project      = var.project_id
  subscription = google_pubsub_subscription.main[each.key].name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${each.value.sa_email}"
}

# DLQ 転送用: Pub/Sub サービスエージェントに DLQ へ publisher + 元 sub への subscriber を付与
resource "google_pubsub_topic_iam_member" "dlq_sa_publisher" {
  for_each = local.topics

  project = var.project_id
  topic   = google_pubsub_topic.dlq[each.key].name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_pubsub_subscription_iam_member" "dlq_sa_subscriber" {
  for_each = local.subscriptions

  project      = var.project_id
  subscription = google_pubsub_subscription.main[each.key].name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# ──────────────────────────────────────────────
# state migration (Level 2 refactor: 旧トピック別 resource 名から for_each map へ)
# ──────────────────────────────────────────────

# --- topics: main ---
moved {
  from = google_pubsub_topic.matchmaking_events
  to   = google_pubsub_topic.main["matchmaking_events"]
}
moved {
  from = google_pubsub_topic.faction_purchased
  to   = google_pubsub_topic.main["faction_purchased"]
}
moved {
  from = google_pubsub_topic.premium_updated
  to   = google_pubsub_topic.main["premium_updated"]
}
moved {
  from = google_pubsub_topic.player_onboarded
  to   = google_pubsub_topic.main["player_onboarded"]
}
moved {
  from = google_pubsub_topic.news_article_collected
  to   = google_pubsub_topic.main["news_article_collected"]
}

# --- topics: DLQ ---
moved {
  from = google_pubsub_topic.matchmaking_events_dlq
  to   = google_pubsub_topic.dlq["matchmaking_events"]
}
moved {
  from = google_pubsub_topic.faction_purchased_dlq
  to   = google_pubsub_topic.dlq["faction_purchased"]
}
moved {
  from = google_pubsub_topic.premium_updated_dlq
  to   = google_pubsub_topic.dlq["premium_updated"]
}
moved {
  from = google_pubsub_topic.player_onboarded_dlq
  to   = google_pubsub_topic.dlq["player_onboarded"]
}
moved {
  from = google_pubsub_topic.news_article_collected_dlq
  to   = google_pubsub_topic.dlq["news_article_collected"]
}

# --- subscriptions ---
moved {
  from = google_pubsub_subscription.matchmaking_events_gateway
  to   = google_pubsub_subscription.main["matchmaking_events.gateway"]
}
moved {
  from = google_pubsub_subscription.faction_purchased["account"]
  to   = google_pubsub_subscription.main["faction_purchased.account"]
}
moved {
  from = google_pubsub_subscription.faction_purchased["card"]
  to   = google_pubsub_subscription.main["faction_purchased.card"]
}
moved {
  from = google_pubsub_subscription.faction_purchased["gateway"]
  to   = google_pubsub_subscription.main["faction_purchased.gateway"]
}
moved {
  from = google_pubsub_subscription.premium_updated["account"]
  to   = google_pubsub_subscription.main["premium_updated.account"]
}
moved {
  from = google_pubsub_subscription.premium_updated["gateway"]
  to   = google_pubsub_subscription.main["premium_updated.gateway"]
}
moved {
  from = google_pubsub_subscription.player_onboarded["account"]
  to   = google_pubsub_subscription.main["player_onboarded.account"]
}
moved {
  from = google_pubsub_subscription.player_onboarded["card"]
  to   = google_pubsub_subscription.main["player_onboarded.card"]
}
moved {
  from = google_pubsub_subscription.player_onboarded["gateway"]
  to   = google_pubsub_subscription.main["player_onboarded.gateway"]
}
moved {
  from = google_pubsub_subscription.news_article_collected_news
  to   = google_pubsub_subscription.main["news_article_collected.news"]
}

# --- publisher IAM ---
moved {
  from = google_pubsub_topic_iam_member.matchmaking_publisher
  to   = google_pubsub_topic_iam_member.publisher["matchmaking_events"]
}
moved {
  from = google_pubsub_topic_iam_member.faction_purchased_shop_publisher
  to   = google_pubsub_topic_iam_member.publisher["faction_purchased"]
}
moved {
  from = google_pubsub_topic_iam_member.premium_updated_shop_publisher
  to   = google_pubsub_topic_iam_member.publisher["premium_updated"]
}
moved {
  from = google_pubsub_topic_iam_member.player_onboarded_scenario_publisher
  to   = google_pubsub_topic_iam_member.publisher["player_onboarded"]
}
moved {
  from = google_pubsub_topic_iam_member.news_article_collected_newsfeed_publisher
  to   = google_pubsub_topic_iam_member.publisher["news_article_collected"]
}

# --- subscriber IAM ---
moved {
  from = google_pubsub_subscription_iam_member.gateway_subscriber
  to   = google_pubsub_subscription_iam_member.subscriber["matchmaking_events.gateway"]
}
moved {
  from = google_pubsub_subscription_iam_member.faction_purchased_account
  to   = google_pubsub_subscription_iam_member.subscriber["faction_purchased.account"]
}
moved {
  from = google_pubsub_subscription_iam_member.faction_purchased_card
  to   = google_pubsub_subscription_iam_member.subscriber["faction_purchased.card"]
}
moved {
  from = google_pubsub_subscription_iam_member.faction_purchased_gateway
  to   = google_pubsub_subscription_iam_member.subscriber["faction_purchased.gateway"]
}
moved {
  from = google_pubsub_subscription_iam_member.premium_updated_account
  to   = google_pubsub_subscription_iam_member.subscriber["premium_updated.account"]
}
moved {
  from = google_pubsub_subscription_iam_member.premium_updated_gateway
  to   = google_pubsub_subscription_iam_member.subscriber["premium_updated.gateway"]
}
moved {
  from = google_pubsub_subscription_iam_member.player_onboarded_account
  to   = google_pubsub_subscription_iam_member.subscriber["player_onboarded.account"]
}
moved {
  from = google_pubsub_subscription_iam_member.player_onboarded_card
  to   = google_pubsub_subscription_iam_member.subscriber["player_onboarded.card"]
}
moved {
  from = google_pubsub_subscription_iam_member.player_onboarded_gateway
  to   = google_pubsub_subscription_iam_member.subscriber["player_onboarded.gateway"]
}
moved {
  from = google_pubsub_subscription_iam_member.news_article_collected_news_subscriber
  to   = google_pubsub_subscription_iam_member.subscriber["news_article_collected.news"]
}

# --- DLQ SA publisher IAM ---
moved {
  from = google_pubsub_topic_iam_member.dlq_service_agent_publisher
  to   = google_pubsub_topic_iam_member.dlq_sa_publisher["matchmaking_events"]
}
moved {
  from = google_pubsub_topic_iam_member.faction_purchased_dlq_sa_publisher
  to   = google_pubsub_topic_iam_member.dlq_sa_publisher["faction_purchased"]
}
moved {
  from = google_pubsub_topic_iam_member.premium_updated_dlq_sa_publisher
  to   = google_pubsub_topic_iam_member.dlq_sa_publisher["premium_updated"]
}
moved {
  from = google_pubsub_topic_iam_member.player_onboarded_dlq_sa_publisher
  to   = google_pubsub_topic_iam_member.dlq_sa_publisher["player_onboarded"]
}
moved {
  from = google_pubsub_topic_iam_member.news_article_collected_dlq_sa_publisher
  to   = google_pubsub_topic_iam_member.dlq_sa_publisher["news_article_collected"]
}

# --- DLQ SA subscriber IAM ---
moved {
  from = google_pubsub_subscription_iam_member.dlq_service_agent_subscriber
  to   = google_pubsub_subscription_iam_member.dlq_sa_subscriber["matchmaking_events.gateway"]
}
moved {
  from = google_pubsub_subscription_iam_member.faction_purchased_dlq_sa_subscriber["account"]
  to   = google_pubsub_subscription_iam_member.dlq_sa_subscriber["faction_purchased.account"]
}
moved {
  from = google_pubsub_subscription_iam_member.faction_purchased_dlq_sa_subscriber["card"]
  to   = google_pubsub_subscription_iam_member.dlq_sa_subscriber["faction_purchased.card"]
}
moved {
  from = google_pubsub_subscription_iam_member.faction_purchased_dlq_sa_subscriber["gateway"]
  to   = google_pubsub_subscription_iam_member.dlq_sa_subscriber["faction_purchased.gateway"]
}
moved {
  from = google_pubsub_subscription_iam_member.premium_updated_dlq_sa_subscriber["account"]
  to   = google_pubsub_subscription_iam_member.dlq_sa_subscriber["premium_updated.account"]
}
moved {
  from = google_pubsub_subscription_iam_member.premium_updated_dlq_sa_subscriber["gateway"]
  to   = google_pubsub_subscription_iam_member.dlq_sa_subscriber["premium_updated.gateway"]
}
moved {
  from = google_pubsub_subscription_iam_member.player_onboarded_dlq_sa_subscriber["account"]
  to   = google_pubsub_subscription_iam_member.dlq_sa_subscriber["player_onboarded.account"]
}
moved {
  from = google_pubsub_subscription_iam_member.player_onboarded_dlq_sa_subscriber["card"]
  to   = google_pubsub_subscription_iam_member.dlq_sa_subscriber["player_onboarded.card"]
}
moved {
  from = google_pubsub_subscription_iam_member.player_onboarded_dlq_sa_subscriber["gateway"]
  to   = google_pubsub_subscription_iam_member.dlq_sa_subscriber["player_onboarded.gateway"]
}
moved {
  from = google_pubsub_subscription_iam_member.news_article_collected_dlq_sa_subscriber
  to   = google_pubsub_subscription_iam_member.dlq_sa_subscriber["news_article_collected.news"]
}
