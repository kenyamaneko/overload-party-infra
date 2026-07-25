resource "google_project_service" "run" {
  project            = var.project_id
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_cloud_run_v2_service" "account" {
  name                = "account"
  project             = var.project_id
  location            = var.region
  deletion_protection = false

  ingress = "INGRESS_TRAFFIC_ALL"

  # CI/CD が gcloud でデプロイするたび image が書き換わるため drift を許容する。
  # env/SQL/IAM/インスタンス数の config は Terraform が所有し、CI は image のみ更新する。
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
        container_port = 9090
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
        name  = "DATABASE_CONN"
        value = "host=/cloudsql/${var.cloudsql_connection_name} port=5432 dbname=${var.database_name} sslmode=disable"
      }
      env {
        name  = "GOOGLE_CLOUD_PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "FACTION_ACQUIRED_SUBSCRIPTION"
        value = var.faction_acquired_subscription
      }
      env {
        name  = "PREMIUM_UPDATED_SUBSCRIPTION"
        value = var.premium_updated_subscription
      }
      env {
        name  = "PLAYER_ONBOARDED_SUBSCRIPTION"
        value = var.player_onboarded_subscription
      }
      env {
        name  = "ONBOARDING_NAME_SET_SUBSCRIPTION"
        value = var.onboarding_name_set_subscription
      }
      env {
        name  = "ONBOARDING_FACTION_SET_SUBSCRIPTION"
        value = var.onboarding_faction_set_subscription
      }
      # config.go は "production" | "local" のみ許容するため、クラウド実行では "production" を渡す。
      env {
        name  = "LOG_MODE"
        value = "production"
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
          port = 9090
        }
        initial_delay_seconds = 5
        period_seconds        = 10
        failure_threshold     = 3
      }

      liveness_probe {
        http_get {
          path = "/health"
          port = 9090
        }
        initial_delay_seconds = 10
        period_seconds        = 30
      }
    }
  }
}
