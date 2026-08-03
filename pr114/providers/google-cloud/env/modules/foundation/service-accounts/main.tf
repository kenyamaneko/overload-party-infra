resource "google_service_account" "accounts" {
  for_each = local.all_services

  project      = var.project_id
  account_id   = each.value
  display_name = "Overload Party ${title(each.key)}"
}

