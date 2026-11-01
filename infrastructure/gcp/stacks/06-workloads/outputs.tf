# -----------------------------------------------------------------------------
# ARTIFACT REGISTRY OUTPUTS
# -----------------------------------------------------------------------------

output "artifact_registries" {
  description = "Map of Artifact Registry repositories"
  value = {
    for key, repo in module.artifact_registries : key => {
      id       = repo.id
      name     = repo.name
      location = var.region
      # Docker repository URL format
      repository_url = "${var.region}-docker.pkg.dev/${var.project_id}/${repo.name}"
    }
  }
}

output "docker_registry_url" {
  description = "Base Docker registry URL for this project"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}"
}

# -----------------------------------------------------------------------------
# SECRET MANAGER OUTPUTS
# -----------------------------------------------------------------------------

output "secrets" {
  description = "Map of Secret Manager secrets"
  value = {
    for key, secret in module.secrets : key => {
      id   = secret.id
      name = secret.name
    }
  }
}

# -----------------------------------------------------------------------------
# GITHUB ACTIONS OIDC OUTPUTS
# -----------------------------------------------------------------------------

output "github_oidc_workload_identity_pool" {
  description = "Workload Identity Pool for GitHub Actions"
  value       = var.enable_github_oidc ? google_iam_workload_identity_pool.github[0].name : null
}

output "github_oidc_workload_identity_provider" {
  description = "Workload Identity Provider for GitHub Actions"
  value       = var.enable_github_oidc ? google_iam_workload_identity_pool_provider.github[0].name : null
}

output "github_actions_service_account_email" {
  description = "GitHub Actions service account email"
  value       = var.enable_github_oidc ? module.github_actions_service_account[0].email : null
}

# For use in GitHub Actions workflow
output "github_actions_workload_identity_provider" {
  description = "Full Workload Identity Provider path for GitHub Actions"
  value       = var.enable_github_oidc ? google_iam_workload_identity_pool_provider.github[0].name : null
}

# -----------------------------------------------------------------------------
# MONITORING OUTPUTS
# -----------------------------------------------------------------------------

output "notification_channels" {
  description = "Map of notification channel IDs"
  value = {
    for key, channel in google_monitoring_notification_channel.channels : key => {
      id   = channel.id
      name = channel.display_name
    }
  }
}

output "alert_policies" {
  description = "Map of alert policy IDs"
  value = {
    for key, policy in google_monitoring_alert_policy.policies : key => {
      id   = policy.id
      name = policy.display_name
    }
  }
}

# -----------------------------------------------------------------------------
# EXTERNAL SECRETS OPERATOR OUTPUTS
# -----------------------------------------------------------------------------

output "eso_workloads_service_account_email" {
  description = "ESO service account email for workloads cluster"
  value       = var.enable_external_secrets ? module.eso_workloads_service_account[0].email : null
}

output "eso_runners_service_account_email" {
  description = "ESO service account email for runners cluster"
  value       = var.enable_external_secrets ? module.eso_runners_service_account[0].email : null
}
