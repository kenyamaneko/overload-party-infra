locals {
  # DLQ への転送は散発的にしか起きないため、5 分単位で集計して単発の転送を拾う。
  alert_alignment_period = "300s"

  # 転送が 1 件でも起きれば異常とみなすため、持続時間を追加で設けない。
  immediate_alert_duration = "0s"

  # 転送は散発的で、収束を検知できないため、7 日で自動クローズする。
  auto_close_duration = "604800s"
}

resource "google_monitoring_alert_policy" "dead_letter_message" {
  project      = var.project_id
  display_name = "${var.subscription_name}: DLQ へ通知が転送された"
  combiner     = "OR"

  conditions {
    display_name = "dead letter message count > threshold"

    condition_threshold {
      filter = <<-EOT
        resource.type = "pubsub_subscription"
        AND resource.labels.subscription_id = "${var.subscription_name}"
        AND metric.type = "pubsub.googleapis.com/subscription/dead_letter_message_count"
      EOT

      comparison      = "COMPARISON_GT"
      threshold_value = var.dead_letter_message_count_threshold
      duration        = local.immediate_alert_duration

      aggregations {
        alignment_period     = local.alert_alignment_period
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  notification_channels = var.notification_channel_ids

  alert_strategy {
    auto_close = local.auto_close_duration
  }
}
