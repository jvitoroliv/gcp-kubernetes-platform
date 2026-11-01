# -----------------------------------------------------------------------------
# GKE CLUSTER OUTPUTS
# -----------------------------------------------------------------------------

output "cluster_name" {
  description = "GKE cluster name"
  value       = module.gke_cluster.name
}

output "cluster_id" {
  description = "GKE cluster ID"
  value       = module.gke_cluster.id
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = module.gke_cluster.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  value       = module.gke_cluster.cluster_ca_certificate
  sensitive   = true
}

output "cluster_location" {
  description = "GKE cluster location (region)"
  value       = var.region
}

# -----------------------------------------------------------------------------
# NODE POOL OUTPUTS
# -----------------------------------------------------------------------------

output "node_pools" {
  description = "Map of node pool names to their details"
  value = {
    for key, pool in module.node_pools : key => {
      name = pool.name
    }
  }
}

# -----------------------------------------------------------------------------
# WORKLOAD IDENTITY OUTPUTS
# -----------------------------------------------------------------------------

output "workload_identity_pool" {
  description = "Workload Identity pool for the cluster"
  value       = "${var.project_id}.svc.id.goog"
}

output "nakama_service_account" {
  description = "Nakama workload identity service account email"
  value       = module.nakama_workload_identity.service_account_email
}

output "lobby_backend_service_account" {
  description = "Lobby Backend workload identity service account email"
  value       = module.lobby_backend_workload_identity.service_account_email
}

output "external_secrets_service_account" {
  description = "External Secrets Operator workload identity service account email"
  value       = module.external_secrets_workload_identity.service_account_email
}

output "argocd_service_account" {
  description = "ArgoCD workload identity service account email"
  value       = module.argocd_workload_identity.service_account_email
}

# -----------------------------------------------------------------------------
# KUBECTL CONNECTION COMMAND
# -----------------------------------------------------------------------------

output "kubectl_connect_command" {
  description = "Command to configure kubectl to connect to this cluster"
  value       = "gcloud container clusters get-credentials ${module.gke_cluster.name} --region ${var.region} --project ${var.project_id}"
}
