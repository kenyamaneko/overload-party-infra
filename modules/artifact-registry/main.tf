# ──────────────────────────────────────────────
# API 有効化
# ──────────────────────────────────────────────

resource "google_project_service" "artifactregistry" {
  project            = var.project_id
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

# ──────────────────────────────────────────────
# コンテナレジストリ
# ──────────────────────────────────────────────

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
}
