resource "google_project_iam_member" "viewer" {
  for_each = toset(var.monitored_projects)

  project = each.value
  role    = "roles/viewer"
  member  = var.deploy_sa_member
}

# バケット IAM ポリシーの読み取りに必要 (viewer だけでは storage.buckets.getIamPolicy が不足)
resource "google_project_iam_member" "security_reviewer" {
  for_each = toset(var.monitored_projects)

  project = each.value
  role    = "roles/iam.securityReviewer"
  member  = var.deploy_sa_member
}

# drift-monitor が infra リポの plan を走らせる際に必要 (providers/google-cloud/env が叩く)
resource "google_project_service" "firebase" {
  project            = var.ops_project_id
  service            = "firebase.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "firebase_hosting" {
  project            = var.ops_project_id
  service            = "firebasehosting.googleapis.com"
  disable_on_destroy = false
}
