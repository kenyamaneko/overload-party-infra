locals {
  # service-monitoring と揃える。瞬間的な揺らぎで発報しないよう 5 分単位で集計する。
  alert_alignment_period = "300s"

  # 資源の逼迫は一時的な尖りで発報させたくないため、閾値超えが 5 分続いたときに発報する。
  sustained_alert_duration = "300s"

  # 集計期間内で閾値を超えた時点をそのまま異常とみなす条件に使う。
  immediate_alert_duration = "0s"

  # 資源の逼迫が収まったことを検知できない条件でもインシデントが残り続けないよう、
  # 7 日で自動クローズする。
  auto_close_duration = "604800s"

  database_id = "${var.project_id}:${var.instance_name}"
}

resource "google_monitoring_alert_policy" "cpu_utilization" {
  project      = var.project_id
  display_name = "Cloud SQL ${var.instance_name}: CPU 使用率が高い"
  combiner     = "OR"

  conditions {
    display_name = "cpu utilization > threshold"

    condition_threshold {
      filter = <<-EOT
        resource.type = "cloudsql_database"
        AND resource.labels.database_id = "${local.database_id}"
        AND metric.type = "cloudsql.googleapis.com/database/cpu/utilization"
      EOT

      comparison      = "COMPARISON_GT"
      threshold_value = var.cpu_utilization_threshold
      duration        = local.sustained_alert_duration

      aggregations {
        alignment_period   = local.alert_alignment_period
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = var.notification_channel_ids

  alert_strategy {
    auto_close = local.auto_close_duration
  }
}

resource "google_monitoring_alert_policy" "memory_utilization" {
  project      = var.project_id
  display_name = "Cloud SQL ${var.instance_name}: メモリ使用率が高い"
  combiner     = "OR"

  conditions {
    display_name = "memory utilization > threshold"

    condition_threshold {
      filter = <<-EOT
        resource.type = "cloudsql_database"
        AND resource.labels.database_id = "${local.database_id}"
        AND metric.type = "cloudsql.googleapis.com/database/memory/utilization"
      EOT

      comparison      = "COMPARISON_GT"
      threshold_value = var.memory_utilization_threshold
      duration        = local.sustained_alert_duration

      aggregations {
        alignment_period   = local.alert_alignment_period
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = var.notification_channel_ids

  alert_strategy {
    auto_close = local.auto_close_duration
  }
}

resource "google_monitoring_alert_policy" "disk_utilization" {
  project      = var.project_id
  display_name = "Cloud SQL ${var.instance_name}: ディスク使用率が高い"
  combiner     = "OR"

  conditions {
    display_name = "disk utilization > threshold"

    condition_threshold {
      filter = <<-EOT
        resource.type = "cloudsql_database"
        AND resource.labels.database_id = "${local.database_id}"
        AND metric.type = "cloudsql.googleapis.com/database/disk/utilization"
      EOT

      comparison      = "COMPARISON_GT"
      threshold_value = var.disk_utilization_threshold
      duration        = local.sustained_alert_duration

      aggregations {
        alignment_period   = local.alert_alignment_period
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = var.notification_channel_ids

  alert_strategy {
    auto_close = local.auto_close_duration
  }
}

# battle は接続プールの上限を設定しておらず、設定から積み上げた上限が実際の接続数と
# 一致しない。上限に触れる前に気づけるよう実測値で見る。
resource "google_monitoring_alert_policy" "connection_count" {
  project      = var.project_id
  display_name = "Cloud SQL ${var.instance_name}: 同時接続数が多い"
  combiner     = "OR"

  conditions {
    display_name = "connection count > threshold"

    condition_threshold {
      filter = <<-EOT
        resource.type = "cloudsql_database"
        AND resource.labels.database_id = "${local.database_id}"
        AND metric.type = "cloudsql.googleapis.com/database/postgresql/num_backends"
      EOT

      comparison      = "COMPARISON_GT"
      threshold_value = var.connection_count_threshold
      duration        = local.immediate_alert_duration

      # 接続の枯渇は起きた瞬間に接続拒否として利用者に出る。平均に均すと取り逃すため
      # 窓内のピークで見て、継続時間も設けない。
      aggregations {
        alignment_period     = local.alert_alignment_period
        per_series_aligner   = "ALIGN_MAX"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  notification_channels = var.notification_channel_ids

  alert_strategy {
    auto_close = local.auto_close_duration
  }
}
