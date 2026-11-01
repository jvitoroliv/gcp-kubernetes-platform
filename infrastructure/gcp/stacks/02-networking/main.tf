# -----------------------------------------------------------------------------
# NETWORKING STACK
# This stack sets up the core networking infrastructure:
# - VPC network
# - Subnet with secondary ranges for GKE pods/services
# - Cloud Router and Cloud NAT
# - Firewall rules
# -----------------------------------------------------------------------------

locals {
  common_labels = merge({
    project     = "gameplatform"
    environment = var.environment
    component   = "networking"
    managed_by  = "terraform"
  }, var.labels)

  # Naming convention
  name_prefix = "gameplatform-${var.environment}"
  vpc_name    = var.vpc_name != "" ? var.vpc_name : "${local.name_prefix}-vpc"
}

# -----------------------------------------------------------------------------
# VPC NETWORK
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
# MAIN SUBNET
# Single subnet with secondary ranges for GKE pods and services
# -----------------------------------------------------------------------------

module "subnet" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/subnet"

  name                     = "${local.name_prefix}-subnet"
  ip_cidr_range            = var.subnet_cidr
  region                   = var.region
  network                  = module.vpc.self_link
  project                  = var.project_id
  private_ip_google_access = true

  secondary_ip_ranges = concat(
    [
      {
        range_name    = "pods"
        ip_cidr_range = var.pods_cidr
      },
      {
        range_name    = "services"
        ip_cidr_range = var.services_cidr
      }
    ],
    var.enable_runners_ranges ? [
      {
        range_name    = "pods-runners"
        ip_cidr_range = var.pods_runners_cidr
      },
      {
        range_name    = "services-runners"
        ip_cidr_range = var.services_runners_cidr
      }
    ] : []
  )

  log_config = var.enable_flow_logs ? {
    aggregation_interval = var.flow_logs_interval
    flow_sampling        = var.flow_logs_sampling
    metadata             = "INCLUDE_ALL_METADATA"
  } : null
}

# -----------------------------------------------------------------------------
# CLOUD ROUTER
# Required for Cloud NAT
# -----------------------------------------------------------------------------

module "cloud_router" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/cloud-router"
  count  = var.enable_cloud_nat ? 1 : 0

  name        = "${local.name_prefix}-router"
  network     = module.vpc.self_link
  region      = var.region
  project     = var.project_id
  description = "Cloud Router for ${var.environment} environment"
}

# -----------------------------------------------------------------------------
# CLOUD NAT
# Allows private GKE nodes to access the internet
# -----------------------------------------------------------------------------

module "cloud_nat" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/cloud-nat"
  count  = var.enable_cloud_nat ? 1 : 0

  name                               = "${local.name_prefix}-nat"
  router                             = module.cloud_router[0].name
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

# Allow internal communication within VPC
module "firewall_internal" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/firewall-rule"
  count  = var.enable_default_firewall_rules ? 1 : 0

  name        = "${local.name_prefix}-allow-internal"
  network     = module.vpc.name
  project     = var.project_id
  direction   = "INGRESS"
  priority    = 1000
  description = "Allow internal communication within VPC"

  source_ranges = [var.subnet_cidr, var.pods_cidr, var.services_cidr]

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
  count  = var.enable_default_firewall_rules ? 1 : 0

  name        = "${local.name_prefix}-allow-health-checks"
  network     = module.vpc.name
  project     = var.project_id
  direction   = "INGRESS"
  priority    = 1000
  description = "Allow Google Cloud health check probes"

  # Google Cloud health check source ranges
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]

  allow_rules = [
    {
      protocol = "tcp"
      ports    = []
    }
  ]
}

# Allow IAP (Identity-Aware Proxy) for SSH access
module "firewall_iap" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/firewall-rule"
  count  = var.enable_default_firewall_rules ? 1 : 0

  name        = "${local.name_prefix}-allow-iap"
  network     = module.vpc.name
  project     = var.project_id
  direction   = "INGRESS"
  priority    = 1000
  description = "Allow IAP for SSH and kubectl access"

  # IAP source range
  source_ranges = ["35.235.240.0/20"]

  allow_rules = [
    {
      protocol = "tcp"
      ports    = ["22", "443"]
    }
  ]
}

# Allow GKE master to node communication
module "firewall_gke_master" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/firewall-rule"
  count  = var.enable_default_firewall_rules ? 1 : 0

  name        = "${local.name_prefix}-allow-gke-master"
  network     = module.vpc.name
  project     = var.project_id
  direction   = "INGRESS"
  priority    = 1000
  description = "Allow GKE master to communicate with nodes"

  source_ranges = var.enable_runners_ranges ? [var.master_ipv4_cidr, var.master_runners_ipv4_cidr] : [var.master_ipv4_cidr]

  allow_rules = [
    {
      protocol = "tcp"
      ports    = ["443", "10250", "8443"]
    }
  ]
}

# -----------------------------------------------------------------------------
# PRIVATE SERVICE NETWORKING
# Required for Cloud SQL private IP
# -----------------------------------------------------------------------------

resource "google_compute_global_address" "private_service_range" {
  name          = "${local.name_prefix}-private-services"
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
