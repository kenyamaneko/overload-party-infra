# 複数 module が共通で使う API はここに集約し、module 単位での重複宣言を避ける。
# 単一 module でしか使わない API (sqladmin / firebase 等) は各 module 側で enable する。
resource "google_project_service" "secretmanager" {
  project            = var.project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "run" {
  project            = var.project_id
  service            = "run.googleapis.com"
  disable_on_destroy = false
}
