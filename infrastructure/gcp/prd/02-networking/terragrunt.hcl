# =============================================================================
# 02-NETWORKING STACK - PRD ENVIRONMENT
# =============================================================================
# Creates VPC with TWO separate subnets:
# - project-prd-workloads-subnet (for prd workloads cluster)
# - project-prd-runners-subnet (for prd runners cluster - ArgoCD + GitHub Actions)
#
# NOT SHARED - prd has its own isolated infrastructure

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path   = "${get_terragrunt_dir()}/../env.hcl"
  expose = true
}

terraform {
  source = "${get_repo_root()}/stacks/02-networking-prd"
}

dependency "foundation" {
  config_path = "../01-foundation"

  mock_outputs = {
    project_id = "project-prd-env"
  }
}

inputs = {
  project_id = include.env.locals.project_id
  region     = include.env.locals.region

  # VPC Configuration
  vpc_routing_mode = "REGIONAL"

  # =============================================================================
  # WORKLOADS SUBNET CONFIGURATION
  # =============================================================================
  workloads_subnet_cidr   = "10.100.0.0/20"   # 4,096 IPs for nodes
  workloads_pods_cidr     = "10.104.0.0/14"   # 262,144 IPs for pods
  workloads_services_cidr = "10.108.0.0/20"   # 4,096 IPs for services
  workloads_master_cidr   = "172.16.0.0/28"   # GKE master nodes

  # =============================================================================
  # RUNNERS SUBNET CONFIGURATION (ArgoCD + GitHub Actions)
  # =============================================================================
  runners_subnet_cidr   = "10.112.0.0/20"   # 4,096 IPs for nodes
  runners_pods_cidr     = "10.116.0.0/14"   # 262,144 IPs for pods
  runners_services_cidr = "10.120.0.0/20"   # 4,096 IPs for services
  runners_master_cidr   = "172.16.1.0/28"   # GKE master nodes

  # =============================================================================
  # VPN/ON-PREMISES ACCESS
  # =============================================================================
  vpn_cidr_ranges = [
    "10.0.0.0/24", # On-premises network (via VPN)
  ]

  # Cloud NAT Configuration
  nat_min_ports_per_vm = 2048
  nat_enable_logging   = true
  nat_log_filter       = "ERRORS_ONLY"

  # VPC Flow Logs
  enable_flow_logs   = true
  flow_logs_sampling = 0.5
  flow_logs_interval = "INTERVAL_5_SEC"

  labels = {
    environment = "prd"
    project     = "gameplatform"
    managed_by  = "terragrunt"
    owner       = "infrastructure-team"
    cost_center = "production"
  }
}
