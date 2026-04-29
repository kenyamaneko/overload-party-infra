# Cloud SQL 用 PSC エンドポイント (プロジェクト横断)。
#
# 永続リソース (IP, DNS ゾーン, DNS レコード) はここで管理する。
# フォワーディングルールは一時的 -- env-up.sh / env-down.sh で作成/削除し、
# 環境未使用時の $0.025/時間の固定コストを回避する。

resource "google_project_service" "dns" {
  project            = var.project_id
  service            = "dns.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "sqladmin" {
  project            = var.project_id
  service            = "sqladmin.googleapis.com"
  disable_on_destroy = false
}

data "google_sql_database_instance" "target" {
  depends_on = [google_project_service.sqladmin]

  name    = var.cloudsql_instance_name
  project = var.cloudsql_project_id
}

data "google_compute_subnetwork" "default" {
  name    = "default"
  project = var.project_id
  region  = var.region
}

resource "google_compute_address" "psc" {
  name         = "cloudsql-psc-${var.env_name}"
  project      = var.project_id
  region       = var.region
  address_type = "INTERNAL"
  subnetwork   = data.google_compute_subnetwork.default.id
}

locals {
  # dns_name 形式: "{instance_uid}.{project_uid}.{region}.sql.goog."
  # DNS ゾーンはインスタンス UID 以降の全パートをカバーする必要がある。
  dns_name  = data.google_sql_database_instance.target.dns_name
  dns_parts = split(".", local.dns_name)
  dns_zone  = join(".", slice(local.dns_parts, 1, length(local.dns_parts)))
}

resource "google_dns_managed_zone" "psc" {
  depends_on = [google_project_service.dns]

  name       = "cloudsql-psc-${var.env_name}"
  project    = var.project_id
  dns_name   = local.dns_zone
  visibility = "private"

  private_visibility_config {
    networks {
      network_url = "projects/${var.project_id}/global/networks/${var.network}"
    }
  }
}

resource "google_dns_record_set" "psc" {
  name         = data.google_sql_database_instance.target.dns_name
  managed_zone = google_dns_managed_zone.psc.name
  project      = var.project_id
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_address.psc.address]
}

