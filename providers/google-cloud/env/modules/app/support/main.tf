# support は internal (9009, gateway 向け) / admin (9109) / external (9209) の 3 ポートを待ち受けるが、
# Cloud Run が公開できるコンテナポートは 1 つのみのため、gateway が使う internal のみを公開する。

resource "google_project_service" "run" {
  project            = var.project_id
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_cloud_run_v2_service" "support" {
  name                = "support"
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

    vpc_access {
      network_interfaces {
        network    = var.network
        subnetwork = var.subnetwork
      }
      egress = "PRIVATE_RANGES_ONLY"
    }

    containers {
      image = var.image

      ports {
        container_port = 9009
      }

      resources {
        limits = {
          cpu    = var.resources_limit_cpu
          memory = var.resources_limit_memory
        }

        cpu_idle = true
      }

      env {
        name  = "INTERNAL_PORT"
        value = "9009"
      }
      env {
        name  = "ADMIN_PORT"
        value = "9109"
      }
      env {
        name  = "EXTERNAL_PORT"
        value = "9209"
      }
      env {
        name  = "ENV"
        value = var.env_name
      }
      env {
        name  = "DATABASE_CONN"
        value = "user=${trimsuffix(var.service_account_email, ".gserviceaccount.com")} dbname=${var.database_name} sslmode=disable"
      }
      env {
        name  = "DATABASE_IAM_AUTH_ENABLED"
        value = "true"
      }
      env {
        name  = "CLOUDSQL_CONNECTION_NAME"
        value = var.cloudsql_connection_name
      }
      env {
        name  = "CORS_ALLOWED_ORIGINS"
        value = var.cors_allowed_origins
      }
      env {
        name  = "INQUIRY_BODY_SNIPPET_LENGTH"
        value = "200"
      }
      env {
        name  = "SLACK_CHANNEL_ID"
        value = var.slack_channel_id
      }
      env {
        name  = "SENDGRID_FROM_ADDRESS"
        value = var.sendgrid_from_address
      }
      env {
        name  = "SENDGRID_FROM_NAME"
        value = var.sendgrid_from_name
      }
      env {
        name = "SLACK_BOT_TOKEN"
        value_source {
          secret_key_ref {
            secret  = var.slack_bot_token_secret_id
            version = "latest"
          }
        }
      }
      env {
        name = "SENDGRID_API_KEY"
        value_source {
          secret_key_ref {
            secret  = var.sendgrid_api_key_secret_id
            version = "latest"
          }
        }
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
          port = 9009
        }
        initial_delay_seconds = 5
        period_seconds        = 10
        failure_threshold     = 3
      }

      liveness_probe {
        http_get {
          path = "/health"
          port = 9009
        }
        initial_delay_seconds = 10
        period_seconds        = 30
      }
    }
  }
}
