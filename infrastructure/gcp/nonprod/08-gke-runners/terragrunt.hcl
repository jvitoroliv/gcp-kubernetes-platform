# =============================================================================
# 08-GKE-RUNNERS STACK - NONPROD ENVIRONMENT
# =============================================================================
# Dedicated GKE cluster for:
# - ArgoCD (manages dev + stg workloads clusters)
# - GitHub Actions Runners (ARC)
#
# Endpoint: PRIVATE (accessible only via VPN and internal networks)
# This cluster orchestrates deployments to dev and stg

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path   = "${get_terragrunt_dir()}/../env.hcl"
  expose = true
}

terraform {
  source = "${get_repo_root()}/stacks/08-gke-runners"
}

# Use SHARED VPC from nonprod
dependency "networking" {
  config_path = "../02-networking"

  mock_outputs = {
    vpc_self_link            = "projects/project-nonprod-env/global/networks/gameplatform-nonprod-vpc"
    vpc_name                 = "gameplatform-nonprod-vpc"
    runners_subnet_self_link = "projects/project-nonprod-env/regions/us-east1/subnetworks/gameplatform-runners-subnet"
    runners_master_cidr      = "172.16.1.0/28"
    vpn_cidr_ranges          = ["10.0.0.0/24"]
  }
}

dependency "foundation" {
  config_path = "../../dev/01-foundation"  # Use dev foundation for service account

  mock_outputs = {
    gke_node_service_account_email = "project-dev-gke-nodes@project-nonprod-env.iam.gserviceaccount.com"
  }
}

inputs = {
  project_id  = include.env.locals.project_id
  environment = "nonprod"  # Special environment name for runners
  region      = include.env.locals.region

  # Network references (from SHARED nonprod VPC)
  vpc_self_link            = dependency.networking.outputs.vpc_self_link
  vpc_name                 = dependency.networking.outputs.vpc_name
  subnet_self_link         = dependency.networking.outputs.runners_subnet_self_link
  gke_node_service_account = dependency.foundation.outputs.gke_node_service_account_email

  # Secondary ranges for runners cluster
  pods_range_name     = "pods"
  services_range_name = "services"

  # Master CIDR
  master_ipv4_cidr = dependency.networking.outputs.runners_master_cidr

  # GKE Cluster Configuration
  release_channel     = "UNSPECIFIED"  # Disable automatic version upgrades
  deletion_protection = false  # CI cluster can be recreated

  # Node Management - disable auto-upgrades to prevent disruption
  node_auto_upgrade = false
  node_auto_repair  = true  # Keep auto-repair to fix unhealthy nodes

  # =============================================================================
  # PRIVATE CLUSTER - NO PUBLIC ENDPOINT
  # =============================================================================
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
      cidr_block   = "10.120.0.0/20"   # Runners subnet (self)
      display_name = "runners-subnet"
    }
  ]

  # Heavy Runners Pool - for Docker builds, multi-service builds
  heavy_pool_machine_type = "e2-standard-8"  # 8 vCPU, 32GB RAM
  heavy_pool_min_nodes    = 1                 # Always keep 1 node (HA)
  heavy_pool_max_nodes    = 10
  heavy_pool_disk_size    = 100               # GB

  # Infra Pool - for ArgoCD, ESO, ARC controller (always running, NO TAINTS)
  infra_pool_machine_type = "e2-medium"  # 2 vCPU, 4GB RAM
  infra_pool_min_nodes    = 1                 # Always keep 1 node (HA)
  infra_pool_max_nodes    = 2
  infra_pool_disk_size    = 30           # GB

  # Maintenance Window - 4 AM UTC (different from workloads clusters)
  maintenance_start_time = "04:00"

  labels = {
    environment = "nonprod"
    project     = "gameplatform"
    managed_by  = "terragrunt"
    owner       = "infrastructure-team"
    cost_center = "nonprod"
    purpose     = "ci-cd-runners"
  }
}
