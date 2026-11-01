# =============================================================================
# 03-GKE STACK - STG ENVIRONMENT
# =============================================================================
# Private GKE cluster for stg workloads
# - Endpoint: PRIVATE (accessible only via VPN)
# - HTTPS with SSL (similar to prod, but private)

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
    stg_subnet_self_link = "projects/project-nonprod-env/regions/us-east1/subnetworks/project-stg-subnet"
    stg_subnet_cidr      = "10.48.0.0/20"
    stg_master_cidr      = "172.16.2.0/28"
    vpn_cidr_ranges      = ["10.0.0.0/24"]
  }
}

dependency "foundation" {
  config_path = "../01-foundation"

  mock_outputs = {
    gke_node_service_account_email = "project-stg-gke-nodes@project-nonprod-env.iam.gserviceaccount.com"
  }
}

inputs = {
  project_id  = include.env.locals.project_id
  environment = include.env.locals.environment
  region      = include.env.locals.region

  # Network references (from SHARED nonprod VPC)
  vpc_self_link            = dependency.networking.outputs.vpc_self_link
  subnet_self_link         = dependency.networking.outputs.stg_subnet_self_link
  master_ipv4_cidr         = dependency.networking.outputs.stg_master_cidr
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
  deletion_protection      = false  # TEMPORARILY disabled for debugging

  # Node Pools - Same as production for parity testing
  node_pools = {
    general = {
      machine_type   = "e2-standard-4"  # 4 vCPUs, 16GB RAM - SAME AS PRD
      min_node_count = 2
      max_node_count = 10
      disk_size_gb   = 100
      disk_type      = "pd-ssd"
      preemptible    = false  # No preemptible for staging parity
      spot           = false
      labels = {
        pool = "general"
      }
      taints = []
    }
    game-servers = {
      machine_type   = "e2-standard-8"  # 8 vCPUs, 32GB RAM - SAME AS PRD
      min_node_count = 1
      max_node_count = 5
      disk_size_gb   = 100
      disk_type      = "pd-ssd"
      preemptible    = false
      spot           = false
      labels = {
        pool     = "game-servers"
        workload = "nakama"
      }
      taints = [
        {
          key    = "workload"
          value  = "game-server"
          effect = "NO_SCHEDULE"
        }
      ]
    }
  }

  # Maintenance Window - 3 AM UTC on Sunday
  maintenance_start_time = "03:00"

  # Monitoring and Logging - TEMPORARILY simplified for debugging
  monitoring_components     = ["SYSTEM_COMPONENTS"]
  logging_components        = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  enable_managed_prometheus = false

  # Addons
  enable_http_load_balancing            = true
  enable_horizontal_pod_autoscaling     = true
  enable_gce_persistent_disk_csi_driver = true

  labels = {
    environment = "stg"
    project     = "gameplatform"
    managed_by  = "terragrunt"
    owner       = "infrastructure-team"
    cost_center = "stg"
  }
}
