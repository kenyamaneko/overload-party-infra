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
        container_port = 9008
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
        value = "9008"
      }
      env {
        name  = "ENV"
        value = var.env_name
      }
      env {
        name  = "DATABASE_CONN"
        value = "user=${trimsuffix(var.service_account_email, ".gserviceaccount.com")} dbname=${var.database_name} sslmode=disable pool_max_conns=${var.db_pool_max_conns}"
      }
      env {
        name  = "DATABASE_IAM_AUTH_ENABLED"
        value = "true"
      }
      env {
        name  = "CLOUDSQL_CONNECTION_NAME"
        value = var.cloudsql_connection_name
      }
      # news の config.go はこの変数名を "_ID" サフィックス無しで読む (他サービスと綴りが異なる)。
      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.project_id
      }
      env {
        name  = "INTERNAL_AUTH_PUBLIC_KEY"
        value = var.internal_auth_public_key
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
