resource "google_project_service" "monitoring" {
  project            = var.project_id
  service            = "monitoring.googleapis.com"
  disable_on_destroy = false
}

locals {
  # 上限到達で新規プレイヤーが接続できなくなる前に気づけるよう、上限の 8 割を早期警戒ラインにする。
  concurrency_alert_threshold = floor(var.max_concurrent_connections * 0.8)

  # request_timeout_sec の間は同一インスタンスが継続する前提のため、短時間に複数回の起動は想定外の再起動とみなす。
  restart_alert_window    = "600s"
  restart_alert_threshold = 1

  # 実トラフィックの実績が無いため、250 接続分の WebSocket ハンドシェイク/keepalive を大きく超える量として暫定的に 10 倍を閾値にする。
  request_count_alert_threshold = var.max_concurrent_connections * 10

  # 同一インシデントの再通知を抑えて通知疲れを防ぐため、5 分間隔にする。
  notification_rate_limit_period = "300s"
}

resource "google_monitoring_alert_policy" "concurrency_near_limit" {
  project      = var.project_id
  display_name = "gateway: 同時接続数が上限に近づいた"
  combiner     = "OR"

  conditions {
    display_name = "active container concurrency > threshold"

    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND resource.labels.service_name = \"${google_cloud_run_v2_service.gateway.name}\" AND metric.type = \"run.googleapis.com/container/max_request_concurrencies\" AND metric.labels.state = \"active\""
      comparison      = "COMPARISON_GT"
      threshold_value = local.concurrency_alert_threshold
      duration        = "60s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_PERCENTILE_99"
      }
    }
  }

  notification_channels = var.alert_notification_channel_ids

  alert_strategy {
    notification_rate_limit {
      period = local.notification_rate_limit_period
    }
  }

  depends_on = [google_project_service.monitoring]
}

resource "google_monitoring_alert_policy" "server_error_response" {
  project      = var.project_id
  display_name = "gateway: 5xx 応答が発生した"
  combiner     = "OR"

  conditions {
    display_name = "5xx response count > 0"

    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND resource.labels.service_name = \"${google_cloud_run_v2_service.gateway.name}\" AND metric.type = \"run.googleapis.com/request_count\" AND metric.labels.response_code_class = \"5xx\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  notification_channels = var.alert_notification_channel_ids

  alert_strategy {
    notification_rate_limit {
      period = local.notification_rate_limit_period
    }
  }

  depends_on = [google_project_service.monitoring]
}

resource "google_monitoring_alert_policy" "instance_restarted" {
  project      = var.project_id
  display_name = "gateway: インスタンスが再起動した"
  combiner     = "OR"

  conditions {
    display_name = "container startup count > threshold within window"

    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND resource.labels.service_name = \"${google_cloud_run_v2_service.gateway.name}\" AND metric.type = \"run.googleapis.com/container/startup_latencies\""
      comparison      = "COMPARISON_GT"
      threshold_value = local.restart_alert_threshold
      duration        = "0s"

      aggregations {
        alignment_period   = local.restart_alert_window
        per_series_aligner = "ALIGN_COUNT"
      }
    }
  }

  notification_channels = var.alert_notification_channel_ids

  alert_strategy {
    notification_rate_limit {
      period = local.notification_rate_limit_period
    }
  }

  depends_on = [google_project_service.monitoring]
}

resource "google_monitoring_alert_policy" "request_count_spike" {
  project      = var.project_id
  display_name = "gateway: リクエスト数が異常に増加した"
  combiner     = "OR"

  conditions {
    display_name = "request count per minute > threshold"

    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND resource.labels.service_name = \"${google_cloud_run_v2_service.gateway.name}\" AND metric.type = \"run.googleapis.com/request_count\""
      comparison      = "COMPARISON_GT"
      threshold_value = local.request_count_alert_threshold
      duration        = "60s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  notification_channels = var.alert_notification_channel_ids

  alert_strategy {
    notification_rate_limit {
      period = local.notification_rate_limit_period
    }
  }

  depends_on = [google_project_service.monitoring]
}
