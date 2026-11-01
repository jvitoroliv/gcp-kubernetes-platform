# -----------------------------------------------------------------------------
# SHARED NETWORKING STACK (NonProd)
# Creates a single VPC with multiple subnets for dev, stg, and runners
# All clusters share the same VPC for internal communication
# -----------------------------------------------------------------------------

locals {
  common_labels = merge({
    project    = "gameplatform"
    component  = "networking"
    managed_by = "terraform"
  }, var.labels)

  vpc_name = "gameplatform-nonprod-vpc"
}

# -----------------------------------------------------------------------------
# VPC NETWORK (Shared)
# -----------------------------------------------------------------------------

module "vpc" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/vpc"

  name                            = local.vpc_name
  project                         = var.project_id
  auto_create_subnetworks         = false
  routing_mode                    = var.vpc_routing_mode
  delete_default_routes_on_create = false

  labels = local.common_labels
}

# -----------------------------------------------------------------------------
# SUBNET: DEV
# -----------------------------------------------------------------------------

module "subnet_dev" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/subnet"

  name                     = "project-dev-subnet"
  ip_cidr_range            = var.dev_subnet_cidr
  region                   = var.region
  network                  = module.vpc.self_link
  project                  = var.project_id
  private_ip_google_access = true

  secondary_ip_ranges = [
    {
      range_name    = "pods"
      ip_cidr_range = var.dev_pods_cidr
    },
    {
      range_name    = "services"
      ip_cidr_range = var.dev_services_cidr
    }
  ]

  log_config = var.enable_flow_logs ? {
    aggregation_interval = var.flow_logs_interval
    flow_sampling        = var.flow_logs_sampling
    metadata             = "INCLUDE_ALL_METADATA"
  } : null
}

# -----------------------------------------------------------------------------
# SUBNET: STG
# -----------------------------------------------------------------------------

module "subnet_stg" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/subnet"

  name                     = "project-stg-subnet"
  ip_cidr_range            = var.stg_subnet_cidr
  region                   = var.region
  network                  = module.vpc.self_link
  project                  = var.project_id
  private_ip_google_access = true

  secondary_ip_ranges = [
    {
      range_name    = "pods"
      ip_cidr_range = var.stg_pods_cidr
    },
    {
      range_name    = "services"
      ip_cidr_range = var.stg_services_cidr
    }
  ]

  log_config = var.enable_flow_logs ? {
    aggregation_interval = var.flow_logs_interval
    flow_sampling        = var.flow_logs_sampling
    metadata             = "INCLUDE_ALL_METADATA"
  } : null
}

# -----------------------------------------------------------------------------
# SUBNET: RUNNERS (for ArgoCD + GitHub Actions Runners)
# -----------------------------------------------------------------------------

module "subnet_runners" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/subnet"

  name                     = "gameplatform-runners-subnet"
  ip_cidr_range            = var.runners_subnet_cidr
  region                   = var.region
  network                  = module.vpc.self_link
  project                  = var.project_id
  private_ip_google_access = true

  secondary_ip_ranges = [
    {
      range_name    = "pods"
      ip_cidr_range = var.runners_pods_cidr
    },
    {
      range_name    = "services"
      ip_cidr_range = var.runners_services_cidr
    }
  ]

  log_config = var.enable_flow_logs ? {
    aggregation_interval = var.flow_logs_interval
    flow_sampling        = var.flow_logs_sampling
    metadata             = "INCLUDE_ALL_METADATA"
  } : null
}

# -----------------------------------------------------------------------------
# CLOUD ROUTER
# -----------------------------------------------------------------------------

module "cloud_router" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/cloud-router"

  name        = "gameplatform-nonprod-router"
  network     = module.vpc.self_link
  region      = var.region
  project     = var.project_id
  description = "Cloud Router for nonprod environment (dev + stg + runners)"
}

# -----------------------------------------------------------------------------
# CLOUD NAT
# -----------------------------------------------------------------------------

module "cloud_nat" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/cloud-nat"

  name                               = "gameplatform-nonprod-nat"
  router                             = module.cloud_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  min_ports_per_vm                   = var.nat_min_ports_per_vm

  log_config = var.nat_enable_logging ? {
    enable = true
    filter = var.nat_log_filter
  } : null

  depends_on = [module.cloud_router]
}

# -----------------------------------------------------------------------------
# FIREWALL RULES
# -----------------------------------------------------------------------------

# Allow internal communication within VPC (all subnets can talk to each other)
module "firewall_internal" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/firewall-rule"

  name        = "gameplatform-nonprod-allow-internal"
  network     = module.vpc.name
  project     = var.project_id
  direction   = "INGRESS"
  priority    = 1000
  description = "Allow internal communication within nonprod VPC"

  source_ranges = [
    var.dev_subnet_cidr,
    var.dev_pods_cidr,
    var.dev_services_cidr,
    var.stg_subnet_cidr,
    var.stg_pods_cidr,
    var.stg_services_cidr,
    var.runners_subnet_cidr,
    var.runners_pods_cidr,
    var.runners_services_cidr,
  ]

  allow_rules = [
    {
      protocol = "tcp"
      ports    = ["0-65535"]
    },
    {
      protocol = "udp"
      ports    = ["0-65535"]
    },
    {
      protocol = "icmp"
      ports    = []
    }
  ]
}

# Allow Google Cloud health check probes
module "firewall_health_checks" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/firewall-rule"

  name        = "gameplatform-nonprod-allow-health-checks"
  network     = module.vpc.name
  project     = var.project_id
  direction   = "INGRESS"
  priority    = 1000
  description = "Allow Google Cloud health check probes"

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]

  allow_rules = [
    {
      protocol = "tcp"
      ports    = []
    }
  ]
}

# Allow IAP for SSH/kubectl access
module "firewall_iap" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/firewall-rule"

  name        = "gameplatform-nonprod-allow-iap"
  network     = module.vpc.name
  project     = var.project_id
  direction   = "INGRESS"
  priority    = 1000
  description = "Allow IAP for SSH and kubectl access"

  source_ranges = ["35.235.240.0/20"]

  allow_rules = [
    {
      protocol = "tcp"
      ports    = ["22", "443"]
    }
  ]
}

# Allow GKE master to node communication (all clusters)
module "firewall_gke_master" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/firewall-rule"

  name        = "gameplatform-nonprod-allow-gke-master"
  network     = module.vpc.name
  project     = var.project_id
  direction   = "INGRESS"
  priority    = 1000
  description = "Allow GKE master to communicate with nodes"

  source_ranges = [
    var.dev_master_cidr,
    var.stg_master_cidr,
    var.runners_master_cidr,
  ]

  allow_rules = [
    {
      protocol = "tcp"
      ports    = ["443", "10250", "8443"]
    }
  ]
}

# Allow VPN network access (on-premises)
module "firewall_vpn" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/firewall-rule"

  name        = "gameplatform-nonprod-allow-vpn"
  network     = module.vpc.name
  project     = var.project_id
  direction   = "INGRESS"
  priority    = 1000
  description = "Allow VPN/on-premises network access"

  source_ranges = var.vpn_cidr_ranges

  allow_rules = [
    {
      protocol = "tcp"
      ports    = ["0-65535"]
    },
    {
      protocol = "udp"
      ports    = ["0-65535"]
    },
    {
      protocol = "icmp"
      ports    = []
    }
  ]
}

# -----------------------------------------------------------------------------
# PRIVATE SERVICE NETWORKING (for Cloud SQL)
# -----------------------------------------------------------------------------

resource "google_compute_global_address" "private_service_range" {
  name          = "gameplatform-nonprod-private-services"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = module.vpc.id

  labels = local.common_labels
}

resource "google_service_networking_connection" "private_service_connection" {
  network                 = module.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_range.name]
}

# -----------------------------------------------------------------------------
# DNS POLICY (Inbound Forwarding for VPN DNS Resolution)
# -----------------------------------------------------------------------------
# Enables VPN clients to resolve private DNS zones (dev.gameplatform, stg.gameplatform)
# by querying the GCP internal DNS resolver

resource "google_dns_policy" "inbound_forwarding" {
  name                      = "gameplatform-nonprod-dns-inbound"
  project                   = var.project_id
  enable_inbound_forwarding = true
  enable_logging            = false
  description               = "Enable inbound DNS forwarding for VPN clients to resolve private zones"

  networks {
    network_url = module.vpc.id
  }
}
