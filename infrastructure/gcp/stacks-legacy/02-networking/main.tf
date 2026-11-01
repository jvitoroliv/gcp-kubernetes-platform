# -----------------------------------------------------------------------------
# NETWORKING STACK - LEGACY
# Creates VPC, subnet, firewall rules, and NAT for Rogues
# -----------------------------------------------------------------------------

locals {
  common_labels = merge({
    project     = "gameplatform"
    environment = var.environment
    component   = "networking"
    managed_by  = "terraform"
  }, var.labels)
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------

module "vpc" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/vpc"

  name                    = var.vpc_name
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  description             = "VPC for legacy services (Rogues, backups)"

  labels = local.common_labels
}

# -----------------------------------------------------------------------------
# SUBNET
# -----------------------------------------------------------------------------

module "subnet" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/subnet"

  name                     = var.subnet_name
  ip_cidr_range            = var.subnet_cidr
  region                   = var.subnet_region
  network                  = module.vpc.self_link
  project                  = var.project_id
  private_ip_google_access = true
  description              = "Main subnet for legacy services"

  depends_on = [module.vpc]
}

# -----------------------------------------------------------------------------
# FIREWALL RULES
# -----------------------------------------------------------------------------

module "firewall_rules" {
  source   = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/firewall-rule"
  for_each = var.firewall_rules

  name        = each.key
  network     = module.vpc.self_link
  project     = var.project_id
  description = each.value.description
  direction   = each.value.direction
  priority    = each.value.priority

  source_ranges      = try(each.value.source_ranges, [])
  destination_ranges = try(each.value.destination_ranges, [])
  target_tags        = try(each.value.target_tags, [])
  source_tags        = try(each.value.source_tags, [])

  allow_rules = try(each.value.allow_rules, [])
  deny_rules  = try(each.value.deny_rules, [])

  depends_on = [module.vpc]
}

# -----------------------------------------------------------------------------
# CLOUD ROUTER (for NAT)
# -----------------------------------------------------------------------------

module "cloud_router" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/cloud-router"
  count  = var.create_nat ? 1 : 0

  name        = "${var.vpc_name}-router"
  network     = module.vpc.self_link
  region      = var.subnet_region
  project     = var.project_id
  description = "Cloud Router for NAT gateway"

  depends_on = [module.vpc]
}

# -----------------------------------------------------------------------------
# CLOUD NAT
# -----------------------------------------------------------------------------

module "cloud_nat" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/cloud-nat"
  count  = var.create_nat ? 1 : 0

  name    = "${var.vpc_name}-nat"
  router  = module.cloud_router[0].name
  region  = var.subnet_region
  project = var.project_id

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  depends_on = [module.cloud_router]
}
