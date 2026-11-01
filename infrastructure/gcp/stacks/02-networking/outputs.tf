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
# SUBNET OUTPUTS
# -----------------------------------------------------------------------------

output "subnet_id" {
  description = "Subnet ID"
  value       = module.subnet.id
}

output "subnet_name" {
  description = "Subnet name"
  value       = module.subnet.name
}

output "subnet_self_link" {
  description = "Subnet self link"
  value       = module.subnet.self_link
}

output "subnet_cidr" {
  description = "Subnet primary CIDR range"
  value       = var.subnet_cidr
}

output "pods_cidr" {
  description = "Secondary CIDR range for GKE pods"
  value       = var.pods_cidr
}

output "services_cidr" {
  description = "Secondary CIDR range for GKE services"
  value       = var.services_cidr
}

output "master_ipv4_cidr" {
  description = "CIDR range for GKE master nodes"
  value       = var.master_ipv4_cidr
}

# -----------------------------------------------------------------------------
# RUNNERS CLUSTER OUTPUTS
# -----------------------------------------------------------------------------

output "pods_runners_cidr" {
  description = "Secondary CIDR range for runners GKE pods"
  value       = var.enable_runners_ranges ? var.pods_runners_cidr : null
}

output "services_runners_cidr" {
  description = "Secondary CIDR range for runners GKE services"
  value       = var.enable_runners_ranges ? var.services_runners_cidr : null
}

output "master_runners_ipv4_cidr" {
  description = "CIDR range for runners GKE master nodes"
  value       = var.enable_runners_ranges ? var.master_runners_ipv4_cidr : null
}

# -----------------------------------------------------------------------------
# CLOUD NAT OUTPUTS
# -----------------------------------------------------------------------------

output "cloud_router_name" {
  description = "Cloud Router name"
  value       = var.enable_cloud_nat ? module.cloud_router[0].name : null
}

output "cloud_nat_name" {
  description = "Cloud NAT name"
  value       = var.enable_cloud_nat ? module.cloud_nat[0].name : null
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
