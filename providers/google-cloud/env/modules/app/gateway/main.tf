# gateway は WebSocket 接続とゲーム進行のインメモリ状態を持つ唯一のコンポーネントのため、
# Cloud Run ではなく GCE の Managed Instance Group で常時起動する。
# GCE には Cloud Run の built-in Cloud SQL connector が無いため、cloud-sql-proxy を konlet の
# マルチコンテナ宣言で併走させる (--auto-iam-authn で自身の runtime SA を使う)。VM は Cloud SQL と
# 同一 VPC 上で稼働するため private IP に直接到達でき、PSC 越しの接続は要らない。

terraform {
  required_providers {
    google = {
      source                = "hashicorp/google"
      configuration_aliases = [google.platform]
    }
  }
}

resource "google_project_service" "compute" {
  project            = var.project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_address" "gateway_static" {
  count = var.use_static_ip ? 1 : 0

  name         = "gateway-static-ip"
  project      = var.project_id
  region       = var.region
  address_type = "EXTERNAL"
}

resource "google_compute_firewall" "gateway_health_check" {
  name    = "gateway-allow-health-check"
  project = var.project_id
  network = var.network

  # Google のヘルスチェッカーの送信元 IP レンジ (Google Cloud 公式ドキュメント記載の固定レンジ)。
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["gateway"]

  allow {
    protocol = "tcp"
    ports    = [tostring(var.container_port)]
  }
}

resource "google_compute_firewall" "gateway_public" {
  name    = "gateway-allow-public"
  project = var.project_id
  network = var.network

  # Cloudflare から gateway への直結 (公開ロードバランサ廃止) のため公開レンジを許可する。
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["gateway"]

  allow {
    protocol = "tcp"
    ports    = [tostring(var.container_port)]
  }
}

locals {
  gateway_env = [
    { name = "PORT", value = tostring(var.container_port) },
    { name = "ENV", value = var.env_name },
    { name = "ALLOWED_ORIGINS", value = var.allowed_origins },
    { name = "BATTLE_SERVER_URL", value = var.battle_service_url },
    { name = "CARD_SERVICE_URL", value = var.card_service_url },
    { name = "MATCHMAKING_SERVICE_URL", value = var.matchmaking_service_url },
    { name = "ACCOUNT_SERVICE_URL", value = var.account_service_url },
    { name = "SHOP_SERVICE_URL", value = var.shop_service_url },
    { name = "SCENARIO_SERVICE_URL", value = var.scenario_service_url },
    { name = "NEWS_SERVICE_URL", value = var.news_service_url },
    { name = "SUPPORT_SERVICE_URL", value = var.support_service_url },
    { name = "DATABASE_CONN", value = "host=127.0.0.1 port=5432 dbname=${var.database_name} sslmode=disable" },
    { name = "GOOGLE_CLOUD_PROJECT_ID", value = var.project_id },
    { name = "MATCHMAKING_SUBSCRIPTION", value = var.matchmaking_subscription },
    { name = "MATCHMAKING_TIMEOUT_SEC", value = tostring(var.matchmaking_timeout_sec) },
  ]

  container_declaration = {
    spec = {
      containers = [
        {
          name  = "gateway"
          image = var.image
          env   = local.gateway_env
          ports = [
            { containerPort = var.container_port }
          ]
          stdin = false
          tty   = false
        },
        {
          name  = "cloud-sql-proxy"
          image = "gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.15.2"
          args = [
            "--structured-logs",
            "--auto-iam-authn",
            "--port=5432",
            var.cloudsql_connection_name,
          ]
          stdin = false
          tty   = false
        },
      ]
      restartPolicy = "Always"
    }
  }
}

# CI の create-versioner がこの template を describe → 複製し、image タグだけ差し替えた
# 新しい template を作成した上で MIG のバージョンをローリング更新する (このリソース自体は
# CI からミューテートされない)。

resource "google_compute_instance_template" "gateway" {
  name_prefix  = "gateway-template-"
  project      = var.project_id
  machine_type = var.machine_type
  tags         = ["gateway"]

  disk {
    source_image = "cos-cloud/cos-stable"
    auto_delete  = true
    boot         = true
    disk_size_gb = 20
    disk_type    = "pd-balanced"
  }

  network_interface {
    network    = var.network
    subnetwork = var.subnetwork

    dynamic "access_config" {
      for_each = var.use_static_ip ? [1] : []
      content {
        nat_ip = google_compute_address.gateway_static[0].address
      }
    }

    dynamic "access_config" {
      for_each = var.use_static_ip ? [] : [1]
      content {}
    }
  }

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  metadata = {
    gce-container-declaration = yamlencode(local.container_declaration)
    google-logging-enabled    = "true"
    google-monitoring-enabled = "true"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_health_check" "gateway" {
  name    = "gateway-autoheal"
  project = var.project_id

  # 起動時に DB プール / Firestore game_config 読み込みを行うため、通常の Cloud Run
  # startup probe より長めの初期猶予を取る。
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = var.container_port
    request_path = "/health"
  }
}

resource "google_compute_region_instance_group_manager" "gateway" {
  name               = "gateway-mig"
  project            = var.project_id
  region             = var.region
  base_instance_name = "gateway"
  target_size        = 1

  version {
    instance_template = google_compute_instance_template.gateway.id
  }

  named_port {
    name = "http"
    port = var.container_port
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.gateway.id
    initial_delay_sec = 300
  }

  # CI がローリング更新で新しい instance_template を指すよう version を書き換えるため、
  # Terraform 側では追随しない。config は Terraform が所有し、image (instance_template の
  # 切り替え) は CI が所有する。
  lifecycle {
    ignore_changes = [version]
  }
}

# Cloud Run 8 サービス分は keyandnotes-platform 側の cloudrun_consumer_project_numbers
# (Cloud Run service agent 経由) で既に付与済みだが、GCE VM のイメージ pull は VM 自身の
# runtime SA の資格情報で行われるため、gateway の runtime SA に対して個別に付与する。

resource "google_artifact_registry_repository_iam_member" "gateway_ar_reader" {
  provider = google.platform

  project    = var.artifact_registry_project_id
  location   = var.artifact_registry_location
  repository = var.artifact_registry_repository_id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.service_account_email}"
}
