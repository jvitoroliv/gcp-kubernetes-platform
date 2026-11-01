# -----------------------------------------------------------------------------
# GKE STACK
# This stack sets up Google Kubernetes Engine:
# - GKE cluster (private, VPC-native)
# - Node pools with autoscaling
# - Workload Identity configuration
# -----------------------------------------------------------------------------

locals {
  common_labels = merge({
    project     = "gameplatform"
    environment = var.environment
    component   = "gke"
    managed_by  = "terraform"
  }, var.labels)

  # Naming convention
  name_prefix  = "gameplatform-${var.environment}"
  cluster_name = var.cluster_name != "" ? var.cluster_name : "${local.name_prefix}-workloads"
}

# -----------------------------------------------------------------------------
# GKE CLUSTER
# -----------------------------------------------------------------------------

module "gke_cluster" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/gke-cluster"

  name        = local.cluster_name
  location    = var.region
  project     = var.project_id
  description = "GamePlatform ${var.environment} GKE cluster"

  network    = var.vpc_self_link
  subnetwork = var.subnet_self_link

  # Release channel for automatic upgrades
  release_channel = var.release_channel

  # VPC-native cluster with IP allocation
  ip_allocation_policy = {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Private cluster configuration
  private_cluster_config = {
    enable_private_nodes    = var.enable_private_nodes
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = var.master_ipv4_cidr
    master_global_access    = var.master_global_access
  }

  # Master authorized networks
  master_authorized_networks = var.master_authorized_networks

  # Workload Identity
  enable_workload_identity = var.enable_workload_identity

  # Maintenance window
  maintenance_window = {
    start_time = var.maintenance_start_time
  }

  # Monitoring and logging
  monitoring_components     = var.monitoring_components
  logging_components        = var.logging_components
  enable_managed_prometheus = var.enable_managed_prometheus

  # Dataplane V2 (eBPF-based, includes native network policy support)
  datapath_provider = "ADVANCED_DATAPATH"

  # Gateway API for custom port TLS termination (like AWS ALB)
  gateway_api_channel = var.gateway_api_channel

  # Addons (network_policy not needed - Dataplane V2 provides native network policy)
  addons_config = {
    http_load_balancing            = var.enable_http_load_balancing
    horizontal_pod_autoscaling     = var.enable_horizontal_pod_autoscaling
    gce_persistent_disk_csi_driver = var.enable_gce_persistent_disk_csi_driver
  }

  # We'll create custom node pools, so remove the default
  remove_default_node_pool = true
  initial_node_count       = 1

  # Protection
  deletion_protection = var.deletion_protection

  labels = local.common_labels
}

# -----------------------------------------------------------------------------
# NODE POOLS
# -----------------------------------------------------------------------------

module "node_pools" {
  source   = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/gke-node-pool"
  for_each = var.node_pools

  name     = "${local.name_prefix}-${each.key}"
  location = var.region
  cluster  = module.gke_cluster.name
  project  = var.project_id

  autoscaling = {
    min_node_count = each.value.min_node_count
    max_node_count = each.value.max_node_count
  }

  auto_upgrade = var.node_auto_upgrade
  auto_repair  = var.node_auto_repair

  node_config = {
    preemptible     = each.value.preemptible
    spot            = each.value.spot
    machine_type    = each.value.machine_type
    disk_size_gb    = each.value.disk_size_gb
    disk_type       = each.value.disk_type
    service_account = var.gke_node_service_account
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    labels = merge(local.common_labels, each.value.labels, {
      node_pool = each.key
    })
    tags   = ["gke-node", "${local.cluster_name}-node"]
    taints = each.value.taints
  }

  enable_workload_identity = var.enable_workload_identity

  depends_on = [module.gke_cluster]
}

# -----------------------------------------------------------------------------
# WORKLOAD IDENTITY BINDINGS
# Service accounts for Kubernetes workloads
# -----------------------------------------------------------------------------

# Nakama workload identity
module "nakama_workload_identity" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/gke-workload-identity"

  project_id         = var.project_id
  project            = var.project_id
  service_account_id = "${local.name_prefix}-nakama"
  display_name       = "Nakama Workload Identity"
  description        = "Service account for Nakama workloads"
  namespace          = "gameplatform-${var.environment}"
  ksa_name           = "nakama"
  roles = [
    "roles/cloudsql.client",
    "roles/secretmanager.secretAccessor",
    "roles/monitoring.metricWriter",
  ]

  depends_on = [module.gke_cluster]
}

# Lobby Backend workload identity
module "lobby_backend_workload_identity" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/gke-workload-identity"

  project_id         = var.project_id
  project            = var.project_id
  service_account_id = "${local.name_prefix}-lobby-backend"
  display_name       = "Lobby Backend Workload Identity"
  description        = "Service account for Lobby Backend workloads"
  namespace          = "gameplatform-${var.environment}"
  ksa_name           = "lobby-backend"
  roles = [
    "roles/cloudsql.client",
    "roles/secretmanager.secretAccessor",
    "roles/monitoring.metricWriter",
  ]

  depends_on = [module.gke_cluster]
}

# External Secrets Operator workload identity
module "external_secrets_workload_identity" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/gke-workload-identity"

  project_id         = var.project_id
  project            = var.project_id
  service_account_id = "${local.name_prefix}-external-secrets"
  display_name       = "External Secrets Workload Identity"
  description        = "Service account for External Secrets Operator"
  namespace          = "external-secrets"
  ksa_name           = "external-secrets"
  roles = [
    "roles/secretmanager.secretAccessor",
    "roles/secretmanager.viewer",
  ]

  depends_on = [module.gke_cluster]
}

# ArgoCD workload identity (for image updater)
module "argocd_workload_identity" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/gke-workload-identity"

  project_id         = var.project_id
  project            = var.project_id
  service_account_id = "${local.name_prefix}-argocd"
  display_name       = "ArgoCD Workload Identity"
  description        = "Service account for ArgoCD Image Updater"
  namespace          = "argocd"
  ksa_name           = "argocd-image-updater"
  roles = [
    "roles/artifactregistry.reader",
  ]

  depends_on = [module.gke_cluster]
}
