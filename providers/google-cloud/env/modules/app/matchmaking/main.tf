# matchmaking は Upstash Redis のみ使用し Postgres へ接続しないため、cloudsql volume /
# Direct VPC Egress を設定しない (他サービスとの唯一の構造上の違い)。
# Upstash 接続情報 (matchmaking-upstash-redis-endpoint / -password) はアプリコード側が
# Secret Manager から直接取得するため env var は不要。secretAccessor は
# providers/upstash/env/modules/matchmaking で既に付与済み。

resource "google_project_service" "run" {
  project            = var.project_id
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_cloud_run_v2_service" "matchmaking" {
  name                = "matchmaking"
  project             = var.project_id
  location            = var.region
  deletion_protection = false

  ingress = "INGRESS_TRAFFIC_ALL"

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
    ]
  }

  template {
    service_account = var.service_account_email

    scaling {
      min_instance_count = 0
      max_instance_count = var.max_instance_count
    }

    containers {
      image = var.image

      ports {
        container_port = 9090
      }

      resources {
        limits = {
          cpu    = var.resources_limit_cpu
          memory = var.resources_limit_memory
        }

        cpu_idle = true
      }

      env {
        name  = "APP_ENV"
        value = "production"
      }
      env {
        name  = "GOOGLE_CLOUD_PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "MATCH_MADE_TOPIC"
        value = var.match_made_topic
      }
      # k8s / ConfigMap のどこにも値の出典が無い暫定値 (ローカル開発用 .env.local.example の
      # 値を踏襲)。本番の閾値としてチューニングされたものではない。
      env {
        name  = "MATCHMAKING_CIRCUIT_THRESHOLD"
        value = "5"
      }
      env {
        name  = "MATCHMAKING_CIRCUIT_COOLDOWN_SEC"
        value = "30"
      }
      env {
        name  = "MATCHMAKING_DRAIN_TIMEOUT_SEC"
        value = "10"
      }
      env {
        name = "INTERNAL_AUTH_SECRET"
        value_source {
          secret_key_ref {
            secret  = var.internal_auth_secret_id
            version = "latest"
          }
        }
      }

      startup_probe {
        http_get {
          path = "/internal/v1/health"
          port = 9090
        }
        initial_delay_seconds = 5
        period_seconds        = 10
        failure_threshold     = 3
      }

      liveness_probe {
        http_get {
          path = "/internal/v1/health"
          port = 9090
        }
        initial_delay_seconds = 10
        period_seconds        = 30
      }
    }
  }
}
