# =============================================================================
# 08-GKE-RUNNERS STACK - PRD ENVIRONMENT
# =============================================================================
# Dedicated GKE cluster for production CI/CD:
# - ArgoCD (manages prd workloads cluster)
# - GitHub Actions Runners (ARC)
#
# NOT SHARED - prd has its own isolated runners cluster
# Endpoint: PRIVATE (accessible only via VPN and internal networks)

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

# Use PRD's own VPC
dependency "networking" {
  config_path = "../02-networking"

  mock_outputs = {
    vpc_self_link           = "projects/project-prd-env/global/networks/project-prd-vpc"
    vpc_name                = "project-prd-vpc"
    runners_subnet_self_link = "projects/project-prd-env/regions/southamerica-east1/subnetworks/project-prd-runners-subnet"
    runners_master_cidr      = "172.16.1.0/28"
  }
}

dependency "foundation" {
  config_path = "../01-foundation"

  mock_outputs = {
    gke_node_service_account_email = "project-prd-gke-nodes@project-prd-env.iam.gserviceaccount.com"
  }
}

inputs = {
  project_id  = include.env.locals.project_id
  environment = include.env.locals.environment
  region      = include.env.locals.region

  # Network references (from PRD 02-networking - runners subnet)
  vpc_self_link            = dependency.networking.outputs.vpc_self_link
  vpc_name                 = dependency.networking.outputs.vpc_name
  subnet_self_link         = dependency.networking.outputs.runners_subnet_self_link
  gke_node_service_account = dependency.foundation.outputs.gke_node_service_account_email

  # Secondary ranges for runners cluster (in runners subnet)
  pods_range_name     = "pods"
  services_range_name = "services"

  # Master CIDR (different from workloads cluster)
  master_ipv4_cidr = dependency.networking.outputs.runners_master_cidr

  # GKE Cluster Configuration
  release_channel     = "UNSPECIFIED"  # Disable automatic version upgrades
  deletion_protection = true           # Protect production infrastructure

  # Node Management - disable auto-upgrades to prevent disruption
  node_auto_upgrade = false
  node_auto_repair  = true  # Keep auto-repair to fix unhealthy nodes

  # =============================================================================
  # PRIVATE CLUSTER - NO PUBLIC ENDPOINT
  # =============================================================================
  master_authorized_networks = [
    {
      cidr_block   = "10.0.0.0/24"     # On-premises network (via VPN)
      display_name = "on-premises-vpn"
    },
    {
      cidr_block   = "10.100.0.0/20"   # PRD workloads subnet (internal)
      display_name = "prd-workloads-subnet"
    },
    {
      cidr_block   = "10.112.0.0/20"   # PRD runners subnet (self)
      display_name = "prd-runners-subnet"
    }
  ]

  # Heavy Runners Pool - for Docker builds, multi-service builds
  heavy_pool_machine_type = "e2-standard-8"  # 8 vCPU, 32GB RAM
  heavy_pool_min_nodes    = 1                 # Always keep 1 node (HA)
  heavy_pool_max_nodes    = 5
  heavy_pool_disk_size    = 100               # GB

  # Infra Pool - for ArgoCD, ESO, ARC controller (always running, NO TAINTS)
  infra_pool_machine_type = "e2-medium"  # 2 vCPU, 4GB RAM
  infra_pool_min_nodes    = 1
  infra_pool_max_nodes    = 2
  infra_pool_disk_size    = 30           # GB

  # Maintenance Window - 5 AM UTC (different from workloads cluster)
  maintenance_start_time = "05:00"

  labels = {
    environment = "prd"
    project     = "gameplatform"
    managed_by  = "terragrunt"
    owner       = "infrastructure-team"
    cost_center = "production"
    purpose     = "ci-cd-runners"
  }
}
