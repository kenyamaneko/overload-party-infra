locals {
  topics = {
    matchmaking_events = {
      topic_name   = "matchmaking-events"
      publisher_sa = var.matchmaking_service_account_email
      subscribers = {
        gateway = { sub_name = "matchmaking-events-gateway", sa_email = var.gateway_service_account_email }
      }
    }
    faction_acquired = {
      topic_name   = "faction-acquired"
      publisher_sa = var.shop_service_account_email
      subscribers = {
        account = { sub_name = "faction-acquired-account-sub", sa_email = var.account_service_account_email }
      }
    }
    card_pack_purchased = {
      topic_name   = "card-pack-purchased"
      publisher_sa = var.shop_service_account_email
      subscribers = {
        card = { sub_name = "card-pack-purchased-card-sub", sa_email = var.card_service_account_email }
      }
    }
    premium_updated = {
      topic_name   = "premium-updated"
      publisher_sa = var.shop_service_account_email
      subscribers = {
        account = { sub_name = "premium-updated-account-sub", sa_email = var.account_service_account_email }
      }
    }
    player_onboarded = {
      topic_name   = "player-onboarded"
      publisher_sa = var.scenario_service_account_email
      subscribers = {
        account = { sub_name = "player-onboarded-account-sub", sa_email = var.account_service_account_email }
        card    = { sub_name = "player-onboarded-card-sub", sa_email = var.card_service_account_email }
      }
    }
    onboarding_name_set = {
      topic_name   = "onboarding-name-set"
      publisher_sa = var.scenario_service_account_email
      subscribers = {
        account = { sub_name = "onboarding-name-set-account-sub", sa_email = var.account_service_account_email }
      }
    }
    onboarding_faction_set = {
      topic_name   = "onboarding-faction-set"
      publisher_sa = var.scenario_service_account_email
      subscribers = {
        account = { sub_name = "onboarding-faction-set-account-sub", sa_email = var.account_service_account_email }
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

  # Pub/Sub はトラフィックの無い subscription を一定期間後に自動削除する。terraform がライフサイクル所有者のためこれを無効化する
  expiration_policy {
    ttl = ""
  }

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

# dead_letter_policy を使った DLQ 転送は Pub/Sub サービスエージェントが行うため、
# ユーザー SA とは別にサービスエージェントへの IAM 付与が必要。これがないと DLQ に転送されず
# max_delivery_attempts に達したメッセージがサイレントに消える。
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
