# =============================================================================
# 07-VPN-BASTION STACK - NONPROD ENVIRONMENT
# =============================================================================
# Shared VPN gateway and bastion host for all nonprod clusters (dev + stg)
# WireGuard VPN for secure access to private GKE clusters

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
    vpc_self_link           = "projects/project-nonprod-env/global/networks/gameplatform-nonprod-vpc"
    vpc_name                = "gameplatform-nonprod-vpc"
    runners_subnet_self_link = "projects/project-nonprod-env/regions/us-east1/subnetworks/gameplatform-runners-subnet"
  }
}

inputs = {
  project_id  = include.env.locals.project_id
  environment = include.env.locals.environment
  region      = include.env.locals.region

  # Network references (from nonprod 02-networking outputs)
  # Use runners subnet for bastion since it's the management/operations subnet
  vpc_self_link    = dependency.networking.outputs.vpc_self_link
  vpc_name         = dependency.networking.outputs.vpc_name
  subnet_self_link = dependency.networking.outputs.runners_subnet_self_link

  # VPN Configuration
  cloud_router_asn = 64512
  peer_asn         = 65001

  # Leave empty initially - VPN gateway will be created without tunnels
  # Once you have your VPN device ready, update these values:
  peer_vpn_gateway_ip = ""
  vpn_shared_secret   = ""

  # Your on-premises/local network CIDR
  # IMPORTANT: Make sure this doesn't overlap with GCP VPC CIDRs
  on_premises_cidr = "10.0.0.0/24"

  # Use static routes instead of BGP (simpler for home/small office)
  enable_bgp = false

  # Additional IP ranges to advertise (if using BGP)
  advertised_ip_ranges = []

  # Bastion Host Configuration
  enable_bastion             = true
  bastion_zone               = "us-east1-b"
  bastion_machine_type       = "e2-micro"  # Smallest instance (free tier eligible)
  bastion_image              = "debian-cloud/debian-12"
  bastion_disk_size          = 20
  bastion_enable_external_ip = true

  # WireGuard VPN
  enable_wireguard = true

  # WireGuard VPN network ranges (nonprod - shared by dev and stg)
  # Includes: dev workloads subnet/pods/services, stg workloads subnet/pods/services,
  #           runners subnet/pods/services, Cloud SQL, GKE masters
  wireguard_vpc_networks = "10.48.0.0/20,10.52.0.0/14,10.56.0.0/20,10.64.0.0/20,10.68.0.0/14,10.72.0.0/20,10.120.0.0/20,10.124.0.0/14,10.128.0.0/20,10.148.0.0/16,172.16.0.0/28,172.16.1.0/28,172.16.2.0/28"

  # DNS servers for VPN clients (kube-dns from dev workloads cluster)
  wireguard_dns_servers = "10.56.0.10,8.8.8.8"

  # Enable SSH from external IPs (needed for direct SSH access)
  enable_ssh_external = true

  # IAM members who can access bastion via IAP
  # Add your email here: "user:your-email@gmail.com"
  # Or a group: "group:devops@your-domain.com"
  iap_members = []

  labels = {
    environment = "nonprod"
    project     = "gameplatform"
    managed_by  = "terragrunt"
    owner       = "infrastructure-team"
    cost_center = "nonprod"
  }
}
