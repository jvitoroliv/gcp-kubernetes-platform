# =============================================================================
# 07-VPN-BASTION STACK - PRD ENVIRONMENT
# =============================================================================
# Dedicated VPN gateway and bastion host for production
# WireGuard VPN for secure access to private GKE cluster
# NOT SHARED - prd has its own isolated infrastructure

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path   = "${get_terragrunt_dir()}/../env.hcl"
  expose = true
}

terraform {
  source = "${get_repo_root()}/stacks/07-vpn-bastion"
}

dependency "networking" {
  config_path = "../02-networking"

  mock_outputs = {
    vpc_self_link           = "projects/project-prd-env/global/networks/project-prd-vpc"
    vpc_name                = "project-prd-vpc"
    runners_subnet_self_link = "projects/project-prd-env/regions/southamerica-east1/subnetworks/project-prd-runners-subnet"
  }
}

inputs = {
  project_id  = include.env.locals.project_id
  environment = include.env.locals.environment
  region      = include.env.locals.region

  # Network references (from prd 02-networking outputs)
  # Use runners subnet for bastion since it's the management/operations subnet
  vpc_self_link    = dependency.networking.outputs.vpc_self_link
  vpc_name         = dependency.networking.outputs.vpc_name
  subnet_self_link = dependency.networking.outputs.runners_subnet_self_link

  # VPN Configuration
  cloud_router_asn = 64514  # Different ASN from nonprod
  peer_asn         = 65003

  # Leave empty initially - VPN gateway will be created without tunnels
  peer_vpn_gateway_ip = ""
  vpn_shared_secret   = ""

  # Your on-premises/local network CIDR
  on_premises_cidr = "10.0.0.0/24"

  # Use static routes instead of BGP
  enable_bgp = false

  # Additional IP ranges to advertise (if using BGP)
  advertised_ip_ranges = []

  # Bastion Host Configuration
  enable_bastion             = true
  bastion_zone               = "southamerica-east1-a"
  bastion_machine_type       = "e2-medium"  # 2 vCPUs, 4GB RAM (upgraded from e2-micro for startup script performance)
  bastion_image              = "debian-cloud/debian-12"
  bastion_disk_size          = 20
  bastion_enable_external_ip = true

  # WireGuard VPN
  enable_wireguard = true

  # WireGuard VPN network ranges (PRD specific)
  # Includes: workloads subnet, workloads pods, workloads services,
  #           runners subnet, runners pods, runners services,
  #           Cloud SQL private services, GKE masters, metadata server
  wireguard_vpc_networks = "10.100.0.0/20,10.104.0.0/14,10.108.0.0/20,10.112.0.0/20,10.116.0.0/14,10.120.0.0/20,10.39.0.0/16,172.16.0.0/28,172.16.1.0/28,169.254.0.0/16"

  # DNS servers for VPN clients (Cloud DNS inbound forwarder resolves private zones)
  wireguard_dns_servers = "10.100.0.2,8.8.8.8"

  # Enable SSH from external IPs (needed for direct SSH access)
  enable_ssh_external = true

  # IAM members who can access bastion via IAP
  iap_members = []

  labels = {
    environment = "prd"
    project     = "gameplatform"
    managed_by  = "terragrunt"
    owner       = "infrastructure-team"
    cost_center = "production"
  }
}
