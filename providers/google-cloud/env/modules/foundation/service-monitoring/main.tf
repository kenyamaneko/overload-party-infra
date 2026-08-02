locals {
  # 単発の事象を拾いつつ瞬間的な揺らぎで発報しないよう、5 分単位で集計する。
  alert_alignment_period = "300s"

  # 集計期間内で閾値を超えた時点をそのまま異常とみなすため、持続時間を追加で設けない。
  immediate_alert_duration = "0s"

  # 収束を検知できない条件でもインシデントが残り続けないよう、7 日で自動クローズする。
  auto_close_duration = "604800s"
}

resource "google_monitoring_alert_policy" "server_error_response" {
  project      = var.project_id
  display_name = "${var.service_name}: 5xx 応答が発生した"
  combiner     = "OR"

  conditions {
    display_name = "5xx response count > threshold"

    condition_threshold {
      filter = <<-EOT
        resource.type = "cloud_run_revision"
        AND resource.labels.service_name = "${var.service_name}"
        AND metric.type = "run.googleapis.com/request_count"
        AND metric.labels.response_code_class = "5xx"
      EOT

      comparison      = "COMPARISON_GT"
      threshold_value = var.server_error_count_threshold
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

resource "google_monitoring_alert_policy" "slow_response" {
  count = var.latency_p95_threshold_ms == null ? 0 : 1

  project      = var.project_id
  display_name = "${var.service_name}: 応答が遅い"
  combiner     = "OR"

  conditions {
    display_name = "p95 latency > threshold"

    condition_threshold {
      filter = <<-EOT
        resource.type = "cloud_run_revision"
        AND resource.labels.service_name = "${var.service_name}"
        AND metric.type = "run.googleapis.com/request_latencies"
      EOT

      comparison      = "COMPARISON_GT"
      threshold_value = var.latency_p95_threshold_ms
      duration        = local.immediate_alert_duration

      aggregations {
        alignment_period     = local.alert_alignment_period
        per_series_aligner   = "ALIGN_PERCENTILE_95"
        cross_series_reducer = "REDUCE_MAX"
      }
    }
  }

  notification_channels = var.notification_channel_ids

  alert_strategy {
    auto_close = local.auto_close_duration
  }
}

# ログベースのメトリクスを定義せずに済むよう、Cloud Logging が標準で出す件数メトリクスを
# severity で絞って使う。
resource "google_monitoring_alert_policy" "error_log_recorded" {
  project      = var.project_id
  display_name = "${var.service_name}: ERROR ログが出た"
  combiner     = "OR"

  conditions {
    display_name = "error log entry count > threshold"

    condition_threshold {
      filter = <<-EOT
        resource.type = "cloud_run_revision"
        AND resource.labels.service_name = "${var.service_name}"
        AND metric.type = "logging.googleapis.com/log_entry_count"
        AND metric.labels.severity = "ERROR"
      EOT

      comparison      = "COMPARISON_GT"
      threshold_value = var.error_log_count_threshold
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
