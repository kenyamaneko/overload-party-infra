resource "google_project_service" "artifactregistry" {
  project            = var.project_id
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "docker" {
  depends_on = [google_project_service.artifactregistry]

  project       = var.project_id
  location      = var.region
  repository_id = var.repository_id
  format        = "DOCKER"

  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"

    most_recent_versions {
      keep_count = 10
    }
  }

  # コスト増加を防ぐため、古いバージョンを削除する
  cleanup_policies {
    id     = "delete-old"
    action = "DELETE"

    condition {
      tag_state = "ANY"
    }
  }
}

# 各環境プロジェクトの Cloud Run がこの AR からイメージをプルするため、
# Cloud Run サービスエージェント（service-<projectNumber>@serverless-robot-prod）に
# reader を付与する。member は該当プロジェクトのプロジェクト番号で一意に決まる。
resource "google_artifact_registry_repository_iam_member" "cloudrun_reader" {
  for_each = var.cloudrun_consumer_project_numbers

  project    = var.project_id
  location   = google_artifact_registry_repository.docker.location
  repository = google_artifact_registry_repository.docker.repository_id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:service-${each.value}@serverless-robot-prod.iam.gserviceaccount.com"
}

# deploy workflow と db-migrate image の push を行う CI SA に writer を付与する。
resource "google_artifact_registry_repository_iam_member" "writer" {
  for_each = toset(var.writer_members)

  project    = var.project_id
  location   = google_artifact_registry_repository.docker.location
  repository = google_artifact_registry_repository.docker.repository_id
  role       = "roles/artifactregistry.writer"
  member     = each.value
}
