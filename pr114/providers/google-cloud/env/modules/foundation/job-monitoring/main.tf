locals {
  # 実行の間隔が空くジョブでは失敗が散発的にしか現れないため、5 分単位で集計して単発の失敗を拾う。
  alert_alignment_period = "300s"

  # 試行が 1 件でも失敗すれば異常とみなすため、持続時間を追加で設けない。
  immediate_alert_duration = "0s"

  # 次の実行まで間隔が空き収束を検知できないため、7 日で自動クローズする。
  auto_close_duration = "604800s"
}

resource "google_monitoring_alert_policy" "task_attempt_failure" {
  project      = var.project_id
  display_name = "${var.job_name}: 実行が失敗した"
  combiner     = "OR"

  conditions {
    display_name = "failed task attempt count > threshold"

    condition_threshold {
      filter = <<-EOT
        resource.type = "cloud_run_job"
        AND resource.labels.job_name = "${var.job_name}"
        AND metric.type = "run.googleapis.com/job/completed_task_attempt_count"
        AND metric.labels.result = "failed"
      EOT

      comparison      = "COMPARISON_GT"
      threshold_value = var.failed_task_attempt_count_threshold
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
