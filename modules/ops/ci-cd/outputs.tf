output "wif_provider" {
  description = "Full resource name of the WIF provider (for GitHub Actions secrets)"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "ci_service_account_email" {
  description = "CI service account email"
  value       = google_service_account.ci.email
}

output "terraform_service_account_email" {
  description = "Terraform deployer service account email"
  value       = google_service_account.terraform.email
}

output "deploy_service_account_email" {
  description = "Deploy service account email (GKE kubectl apply)"
  value       = length(var.deploy_wif_repositories) > 0 ? google_service_account.deploy[0].email : ""
}
