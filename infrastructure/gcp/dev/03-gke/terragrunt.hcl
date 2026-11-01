# =============================================================================
# 03-GKE STACK - DEV ENVIRONMENT
# =============================================================================
# Private GKE cluster for dev workloads
# - Endpoint: PRIVATE (accessible only via VPN)
# - HTTP only (no SSL for internal dev)

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path   = "${get_terragrunt_dir()}/../env.hcl"
  expose = true
}

terraform {
  source = "${get_repo_root()}/stacks/03-gke"
}

# Use SHARED VPC from nonprod
dependency "networking" {
  config_path = "../../nonprod/02-networking"

  mock_outputs = {
    vpc_self_link        = "projects/project-nonprod-env/global/networks/gameplatform-nonprod-vpc"
    dev_subnet_self_link = "projects/project-nonprod-env/regions/us-east1/subnetworks/project-dev-subnet"
    dev_subnet_cidr      = "10.100.0.0/20"
    dev_master_cidr      = "172.16.0.0/28"
    vpn_cidr_ranges      = ["10.0.0.0/24"]
  }
}

dependency "foundation" {
  config_path = "../01-foundation"

  mock_outputs = {
    gke_node_service_account_email = "project-dev-gke-nodes@project-nonprod-env.iam.gserviceaccount.com"
  }
}

inputs = {
  project_id  = include.env.locals.project_id
  environment = include.env.locals.environment
  region      = include.env.locals.region

  # Network references (from SHARED nonprod VPC)
  vpc_self_link            = dependency.networking.outputs.vpc_self_link
  subnet_self_link         = dependency.networking.outputs.dev_subnet_self_link
  master_ipv4_cidr         = dependency.networking.outputs.dev_master_cidr
  gke_node_service_account = dependency.foundation.outputs.gke_node_service_account_email

  # GKE Cluster Configuration
  release_channel = "UNSPECIFIED"  # Disable automatic version upgrades

  # Node Management - disable auto-upgrades to prevent disruption
  node_auto_upgrade = false
  node_auto_repair  = true

  # =============================================================================
  # PRIVATE CLUSTER - NO PUBLIC ENDPOINT
  # =============================================================================
  enable_private_nodes    = true
  enable_private_endpoint = true   # PRIVATE - VPN access only
  master_global_access    = true

  # Master authorized networks - ONLY VPN and internal networks
  master_authorized_networks = [
    {
      cidr_block   = "10.0.0.0/24"     # On-premises network (via VPN)
      display_name = "on-premises-vpn"
    },
    {
      cidr_block   = "10.100.0.0/20"   # Dev subnet (internal)
      display_name = "dev-subnet"
    },
    {
      cidr_block   = "10.48.0.0/20"    # Stg subnet (internal)
      display_name = "stg-subnet"
    },
    {
      cidr_block   = "10.120.0.0/20"   # Runners subnet (ArgoCD access)
      display_name = "runners-subnet"
    },
    {
      cidr_block   = "10.124.0.0/14"   # Runners pod CIDR (ArgoCD pods)
      display_name = "runners-pods"
    }
  ]

  enable_workload_identity = true
  deletion_protection      = false  # Disabled for dev

  # Node Pools - Smaller sizes for dev
  node_pools = {
    general = {
      machine_type   = "e2-standard-2"  # 2 vCPUs, 8GB RAM
      min_node_count = 1
      max_node_count = 3
      disk_size_gb   = 50
      disk_type      = "pd-standard"
      preemptible    = false  # Disabled for HA - preemptible VMs can be terminated
      spot           = false
      labels = {
        pool = "general"
      }
      taints = []
    }
  }

  # Maintenance Window - 3 AM UTC on Sunday
  maintenance_start_time = "03:00"

  # Monitoring and Logging
  monitoring_components     = ["SYSTEM_COMPONENTS"]
  logging_components        = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  enable_managed_prometheus = false  # Disabled for dev to save costs

  # Addons
  enable_http_load_balancing            = true
  enable_horizontal_pod_autoscaling     = true
  enable_gce_persistent_disk_csi_driver = true

  # =============================================================================
  # GATEWAY API - Enables TLS on custom ports (like AWS ALB)
  # =============================================================================
  gateway_api_channel = "CHANNEL_STANDARD"

  labels = {
    environment = "dev"
    project     = "gameplatform"
    managed_by  = "terragrunt"
    owner       = "infrastructure-team"
    cost_center = "development"
  }
}
