# -----------------------------------------------------------------------------
# VPC OUTPUTS
# -----------------------------------------------------------------------------

output "vpc_id" {
  description = "VPC network ID"
  value       = module.vpc.id
}

output "vpc_name" {
  description = "VPC network name"
  value       = module.vpc.name
}

output "vpc_self_link" {
  description = "VPC network self link"
  value       = module.vpc.self_link
}

# -----------------------------------------------------------------------------
# WORKLOADS SUBNET OUTPUTS
# -----------------------------------------------------------------------------

output "workloads_subnet_id" {
  description = "Workloads subnet ID"
  value       = module.subnet_workloads.id
}

output "workloads_subnet_name" {
  description = "Workloads subnet name"
  value       = module.subnet_workloads.name
}

output "workloads_subnet_self_link" {
  description = "Workloads subnet self link"
  value       = module.subnet_workloads.self_link
}

output "workloads_subnet_cidr" {
  description = "Workloads subnet primary CIDR range"
  value       = var.workloads_subnet_cidr
}

output "workloads_pods_cidr" {
  description = "Workloads secondary CIDR range for GKE pods"
  value       = var.workloads_pods_cidr
}

output "workloads_services_cidr" {
  description = "Workloads secondary CIDR range for GKE services"
  value       = var.workloads_services_cidr
}

output "workloads_master_cidr" {
  description = "Workloads CIDR range for GKE master nodes"
  value       = var.workloads_master_cidr
}

# -----------------------------------------------------------------------------
# RUNNERS SUBNET OUTPUTS
# -----------------------------------------------------------------------------

output "runners_subnet_id" {
  description = "Runners subnet ID"
  value       = module.subnet_runners.id
}

output "runners_subnet_name" {
  description = "Runners subnet name"
  value       = module.subnet_runners.name
}

output "runners_subnet_self_link" {
  description = "Runners subnet self link"
  value       = module.subnet_runners.self_link
}

output "runners_subnet_cidr" {
  description = "Runners subnet primary CIDR range"
  value       = var.runners_subnet_cidr
}

output "runners_pods_cidr" {
  description = "Runners secondary CIDR range for GKE pods"
  value       = var.runners_pods_cidr
}

output "runners_services_cidr" {
  description = "Runners secondary CIDR range for GKE services"
  value       = var.runners_services_cidr
}

output "runners_master_cidr" {
  description = "Runners CIDR range for GKE master nodes"
  value       = var.runners_master_cidr
}

# -----------------------------------------------------------------------------
# CLOUD NAT OUTPUTS
# -----------------------------------------------------------------------------

output "cloud_router_name" {
  description = "Cloud Router name"
  value       = module.cloud_router.name
}

output "cloud_nat_name" {
  description = "Cloud NAT name"
  value       = module.cloud_nat.name
}

# -----------------------------------------------------------------------------
# PRIVATE SERVICE CONNECTION
# -----------------------------------------------------------------------------

output "private_service_connection_peering" {
  description = "Private service connection peering name"
  value       = google_service_networking_connection.private_service_connection.peering
}

output "private_service_range_name" {
  description = "Private service IP range name"
  value       = google_compute_global_address.private_service_range.name
}

# -----------------------------------------------------------------------------
# VPN CIDR RANGES (for reference by other stacks)
# -----------------------------------------------------------------------------

output "vpn_cidr_ranges" {
  description = "VPN/on-premises CIDR ranges"
  value       = var.vpn_cidr_ranges
}

# -----------------------------------------------------------------------------
# DNS POLICY
# -----------------------------------------------------------------------------

output "dns_policy_name" {
  description = "DNS policy name for inbound forwarding"
  value       = google_dns_policy.inbound_forwarding.name
}
