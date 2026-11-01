# -----------------------------------------------------------------------------
# OUTPUTS
# -----------------------------------------------------------------------------

output "project_id" {
  description = "GCP project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP region"
  value       = var.region
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

# GKE Node Service Account
output "gke_node_service_account_email" {
  description = "Email of the GKE node service account"
  value       = var.create_gke_service_account ? module.gke_node_service_account[0].email : null
}

output "gke_node_service_account_id" {
  description = "ID of the GKE node service account"
  value       = var.create_gke_service_account ? module.gke_node_service_account[0].id : null
}

# Cloud SQL Service Account
output "cloudsql_service_account_email" {
  description = "Email of the Cloud SQL service account"
  value       = var.create_cloudsql_service_account ? module.cloudsql_service_account[0].email : null
}

output "cloudsql_service_account_id" {
  description = "ID of the Cloud SQL service account"
  value       = var.create_cloudsql_service_account ? module.cloudsql_service_account[0].id : null
}

# Workload Identity Service Accounts
output "workload_identity_service_accounts" {
  description = "Map of workload identity service account emails"
  value = {
    for key, sa in module.workload_identity_service_accounts : key => {
      email = sa.email
      id    = sa.id
    }
  }
}

# APIs Enabled
output "enabled_apis" {
  description = "List of enabled GCP APIs"
  value       = var.enable_apis
}
