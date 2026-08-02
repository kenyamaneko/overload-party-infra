locals {
  budget_warning_threshold_percent  = 0.5
  budget_critical_threshold_percent = 0.75
  budget_exceeded_threshold_percent = 1.0
}

data "google_project" "current" {
  project_id = var.project_id
}

# 請求データの反映に数時間の遅れがあり、上限で止めても超過を防ぎきれないため、通知だけを行う。
# 通知先を指定しない場合の宛先は請求先アカウントの管理者になる。
resource "google_billing_budget" "monthly" {
  billing_account = var.billing_account_id
  display_name    = "${var.project_id}-budget"

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
}
