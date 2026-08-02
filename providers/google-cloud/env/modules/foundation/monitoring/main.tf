resource "google_project_service" "monitoring" {
  project            = var.project_id
  service            = "monitoring.googleapis.com"
  disable_on_destroy = false
}

resource "google_monitoring_notification_channel" "email" {
  project      = var.project_id
  display_name = "Overload Party アラート通知 (${var.env_name})"
  type         = "email"

  labels = {
    email_address = var.alert_email
  }

  depends_on = [google_project_service.monitoring]
}

locals {
  notification_channel_ids = concat(
    [google_monitoring_notification_channel.email.id],
    var.slack_notification_channel_id == "" ? [] : [var.slack_notification_channel_id],
  )

  budget_warning_threshold_percent  = 0.5
  budget_critical_threshold_percent = 0.8
  budget_exceeded_threshold_percent = 1.0
}

data "google_project" "current" {
  project_id = var.project_id
}

# 請求データの反映に数時間の遅れがあり、上限で止めても超過を防ぎきれないため、通知だけを行う。
resource "google_billing_budget" "monthly" {
  billing_account = var.billing_account_id
  display_name    = "Overload Party 月次予算 (${var.env_name})"

  # projects の指定はプロジェクト番号で行う (プロジェクト ID は受け付けない)。
  budget_filter {
    projects = ["projects/${data.google_project.current.number}"]
  }

  amount {
    specified_amount {
      currency_code = "JPY"
      units         = var.monthly_budget_jpy
    }
  }

  threshold_rules {
    threshold_percent = local.budget_warning_threshold_percent
  }

  threshold_rules {
    threshold_percent = local.budget_critical_threshold_percent
  }

  threshold_rules {
    threshold_percent = local.budget_exceeded_threshold_percent
  }

  all_updates_rule {
    monitoring_notification_channels = local.notification_channel_ids
  }
}
