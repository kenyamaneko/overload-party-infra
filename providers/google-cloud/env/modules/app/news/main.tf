# news は internal (9008, gateway 向け) / admin (9108, 運用 UI 向け、IAP 未導入) の
# 2 ポートを listen するが、Cloud Run が公開ルーティングできるコンテナポートは 1 つのみ。
# gateway から到達が必要な internal ポートのみを container_port として公開し、admin ポートは
# Cloud Run の URL からは到達不能のまま (k8s Ingress の IAP 未導入と同じく、運用 UI 経路は
# 別途の設計判断が必要)。

resource "google_project_service" "run" {
  project            = var.project_id
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_cloud_run_v2_service" "news" {
  name                = "news"
  project             = var.project_id
  location            = var.region
  deletion_protection = false

  # 到達制御は呼び出し IAM (run.invoker) が担うため ingress は公開のままにする。
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

    vpc_access {
      network_interfaces {
        network    = var.network
        subnetwork = var.subnetwork
      }
      egress = "PRIVATE_RANGES_ONLY"
    }

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [var.cloudsql_connection_name]
      }
    }

    containers {
      image = var.image

      ports {
        container_port = 9008
      }

      resources {
        limits = {
          cpu    = var.resources_limit_cpu
          memory = var.resources_limit_memory
        }
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }

      env {
        name  = "INTERNAL_PORT"
        value = "9008"
      }
      env {
        name  = "ADMIN_PORT"
        value = "9108"
      }
      env {
        name  = "ENV"
        value = var.env_name
      }
      env {
        name  = "DATABASE_CONN"
        value = "host=/cloudsql/${var.cloudsql_connection_name} port=5432 dbname=${var.database_name} sslmode=disable"
      }
      # news の config.go はこの変数名を "_ID" サフィックス無しで読む (他サービスと綴りが異なる)。
      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.project_id
      }
      env {
        name  = "NEWS_ARTICLE_COLLECTED_SUBSCRIPTION"
        value = var.news_article_collected_subscription
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
          path = "/health"
          port = 9008
        }
        initial_delay_seconds = 5
        period_seconds        = 10
        failure_threshold     = 3
      }

      liveness_probe {
        http_get {
          path = "/health"
          port = 9008
        }
        initial_delay_seconds = 10
        period_seconds        = 30
      }
    }
  }
}
