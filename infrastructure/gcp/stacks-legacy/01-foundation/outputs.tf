output "project_id" {
  description = "GCP project ID"
  value       = var.project_id
}

output "enabled_apis" {
  description = "List of enabled APIs"
  value       = [for api in google_project_service.apis : api.service]
}

output "service_account_emails" {
  description = "Map of service account names to emails"
  value       = { for k, v in module.service_accounts : k => v.email }
}

output "service_account_ids" {
  description = "Map of service account names to IDs"
  value       = { for k, v in module.service_accounts : k => v.id }
}

# -----------------------------------------------------------------------------
# GITHUB ACTIONS OIDC OUTPUTS
# -----------------------------------------------------------------------------

output "workload_identity_provider" {
  description = "Workload Identity Provider for GitHub Actions (for GCP_WORKLOAD_IDENTITY_PROVIDER secret)"
  value       = var.enable_github_oidc ? google_iam_workload_identity_pool_provider.github[0].name : null
}

output "github_actions_service_account_email" {
  description = "GitHub Actions service account email (for GCP_SERVICE_ACCOUNT secret)"
  value       = var.enable_github_oidc ? module.github_actions_service_account[0].email : null
}
