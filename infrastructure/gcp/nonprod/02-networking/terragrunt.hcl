# =============================================================================
# 02-NETWORKING STACK - NONPROD (SHARED VPC)
# =============================================================================
# Creates a single VPC with subnets for:
# - dev-workloads cluster
# - stg-workloads cluster
# - nonprod-runners cluster (ArgoCD + GitHub Actions)
#
# All clusters can communicate internally via private IPs
# External access only via VPN

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path   = "${get_terragrunt_dir()}/../env.hcl"
  expose = true
}

terraform {
  source = "${get_repo_root()}/stacks/02-networking-shared"
}

inputs = {
  project_id = include.env.locals.project_id
  region     = include.env.locals.region

  # VPC Configuration
  vpc_routing_mode = "REGIONAL"

  # =============================================================================
  # DEV SUBNET CONFIGURATION
  # =============================================================================
  dev_subnet_cidr   = "10.100.0.0/20"   # 4,096 IPs for nodes
  dev_pods_cidr     = "10.104.0.0/14"   # 262,144 IPs for pods
  dev_services_cidr = "10.108.0.0/20"   # 4,096 IPs for services
  dev_master_cidr   = "172.16.0.0/28"   # GKE master nodes

  # =============================================================================
  # STG SUBNET CONFIGURATION
  # =============================================================================
  stg_subnet_cidr   = "10.48.0.0/20"    # 4,096 IPs for nodes (48 is /20 aligned)
  stg_pods_cidr     = "10.52.0.0/14"    # 262,144 IPs for pods (52 is /14 aligned)
  stg_services_cidr = "10.64.0.0/20"    # 4,096 IPs for services (64 is /20 aligned)
  stg_master_cidr   = "172.16.2.0/28"   # GKE master nodes

  # =============================================================================
  # RUNNERS SUBNET CONFIGURATION (ArgoCD + GitHub Actions)
  # =============================================================================
  runners_subnet_cidr   = "10.120.0.0/20"  # 4,096 IPs for nodes
  runners_pods_cidr     = "10.124.0.0/14"  # 262,144 IPs for pods
  runners_services_cidr = "10.128.0.0/20"  # 4,096 IPs for services
  runners_master_cidr   = "172.16.1.0/28"  # GKE master nodes

  # =============================================================================
  # VPN/ON-PREMISES ACCESS
  # =============================================================================
  vpn_cidr_ranges = [
    "10.0.0.0/24",    # On-premises network (via VPN)
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
    environment = "nonprod"
    project     = "gameplatform"
    managed_by  = "terragrunt"
    owner       = "infrastructure-team"
    cost_center = "nonprod"
  }
}
