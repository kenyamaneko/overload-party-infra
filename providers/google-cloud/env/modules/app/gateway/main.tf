resource "google_project_service" "run" {
  project            = var.project_id
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_cloud_run_v2_service" "gateway" {
  name                = "gateway"
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
      max_instance_count = 1
    }

    max_instance_request_concurrency = var.max_concurrent_connections

    timeout = "${var.request_timeout_sec}s"

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
        container_port = var.container_port
      }

      resources {
        limits = {
          cpu    = var.resources_limit_cpu
          memory = var.resources_limit_memory
        }

        cpu_idle = true
      }

      env {
        name  = "ENV"
        value = var.env_name
      }
      env {
        name  = "ALLOWED_ORIGINS"
        value = var.allowed_origins
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
        name  = "BATTLE_SERVER_URL"
        value = var.battle_service_url
      }
      env {
        name  = "CARD_SERVICE_URL"
        value = var.card_service_url
      }
      env {
        name  = "MATCHMAKING_SERVICE_URL"
        value = var.matchmaking_service_url
      }
      env {
        name  = "ACCOUNT_SERVICE_URL"
        value = var.account_service_url
      }
      env {
        name  = "SHOP_SERVICE_URL"
        value = var.shop_service_url
      }
      env {
        name  = "SCENARIO_SERVICE_URL"
        value = var.scenario_service_url
      }
      env {
        name  = "NEWS_SERVICE_URL"
        value = var.news_service_url
      }
      env {
        name  = "SUPPORT_SERVICE_URL"
        value = var.support_service_url
      }
      env {
        name  = "GOOGLE_CLOUD_PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "MATCHMAKING_SUBSCRIPTION"
        value = var.matchmaking_subscription
      }
      env {
        name  = "MATCHMAKING_TIMEOUT_SEC"
        value = tostring(var.matchmaking_timeout_sec)
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
          port = var.container_port
        }
        initial_delay_seconds = 5
        period_seconds        = 10
        failure_threshold     = 3
      }

      liveness_probe {
        http_get {
          path = "/health"
          port = var.container_port
        }
        initial_delay_seconds = 10
        period_seconds        = 30
      }
    }
  }
}
