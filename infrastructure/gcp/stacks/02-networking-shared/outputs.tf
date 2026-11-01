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
# DEV SUBNET OUTPUTS
# -----------------------------------------------------------------------------

output "dev_subnet_id" {
  description = "Dev subnet ID"
  value       = module.subnet_dev.id
}

output "dev_subnet_name" {
  description = "Dev subnet name"
  value       = module.subnet_dev.name
}

output "dev_subnet_self_link" {
  description = "Dev subnet self link"
  value       = module.subnet_dev.self_link
}

output "dev_subnet_cidr" {
  description = "Dev subnet primary CIDR range"
  value       = var.dev_subnet_cidr
}

output "dev_pods_cidr" {
  description = "Dev secondary CIDR range for GKE pods"
  value       = var.dev_pods_cidr
}

output "dev_services_cidr" {
  description = "Dev secondary CIDR range for GKE services"
  value       = var.dev_services_cidr
}

output "dev_master_cidr" {
  description = "Dev CIDR range for GKE master nodes"
  value       = var.dev_master_cidr
}

# -----------------------------------------------------------------------------
# STG SUBNET OUTPUTS
# -----------------------------------------------------------------------------

output "stg_subnet_id" {
  description = "Stg subnet ID"
  value       = module.subnet_stg.id
}

output "stg_subnet_name" {
  description = "Stg subnet name"
  value       = module.subnet_stg.name
}

output "stg_subnet_self_link" {
  description = "Stg subnet self link"
  value       = module.subnet_stg.self_link
}

output "stg_subnet_cidr" {
  description = "Stg subnet primary CIDR range"
  value       = var.stg_subnet_cidr
}

output "stg_pods_cidr" {
  description = "Stg secondary CIDR range for GKE pods"
  value       = var.stg_pods_cidr
}

output "stg_services_cidr" {
  description = "Stg secondary CIDR range for GKE services"
  value       = var.stg_services_cidr
}

output "stg_master_cidr" {
  description = "Stg CIDR range for GKE master nodes"
  value       = var.stg_master_cidr
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
# DNS POLICY (Inbound Forwarding)
# -----------------------------------------------------------------------------

output "dns_policy_name" {
  description = "DNS policy name for inbound forwarding"
  value       = google_dns_policy.inbound_forwarding.name
}

output "dns_inbound_forwarder_info" {
  description = "Instructions to get DNS forwarder IPs"
  value       = "Run: gcloud compute addresses list --filter='purpose=DNS_RESOLVER' --project=${var.project_id}"
}
