# PSC エンドポイントは機能的には overload-party 専用 (overload-party-{env} の Cloud SQL に
# 接続するためだけに存在する)。物理的には consumer 側 VPC (keyandnotes-platform) に置く必要が
# あるが (内部 IP は subnet 単位で払い出され別 VPC からは経路が無い)、所有は機能オーナーである
# overload-party-infra の env state に置く。これにより env 追加時に keyandnotes-platform を
# 触らずに、env apply 一発で Cloud SQL → PSC 配線が完結する。
#
# resource の `provider = google.platform` は keyandnotes-platform プロジェクト側に書き込む
# ため。default provider (= overload-party-{env}) では別プロジェクトに書き込めない。

terraform {
  required_providers {
    google = {
      source                = "hashicorp/google"
      configuration_aliases = [google.platform]
    }
  }
}

resource "google_project_service" "dns" {
  provider = google.platform

  project            = var.project_id
  service            = "dns.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "sqladmin" {
  provider = google.platform

  project            = var.project_id
  service            = "sqladmin.googleapis.com"
  disable_on_destroy = false
}

data "google_sql_database_instance" "target" {
  depends_on = [google_project_service.sqladmin]

  provider = google.platform

  name    = var.cloudsql_instance_name
  project = var.cloudsql_project_id
}

data "google_compute_subnetwork" "default" {
  provider = google.platform

  name    = "default"
  project = var.project_id
  region  = var.region
}

resource "google_compute_address" "psc" {
  provider = google.platform

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

  provider = google.platform

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
  provider = google.platform

  name         = data.google_sql_database_instance.target.dns_name
  managed_zone = google_dns_managed_zone.psc.name
  project      = var.project_id
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_address.psc.address]
}
