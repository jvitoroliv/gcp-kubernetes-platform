# =============================================================================
# DEV ENVIRONMENT - NETWORKING STACK
# =============================================================================

project_id  = "project-nonprod-env"
environment = "dev"
region      = "us-east1"

# VPC Configuration
vpc_routing_mode = "REGIONAL"

# Subnet Configuration
# IMPORTANT: Using 10.100.x.x range to avoid conflict with on-premises 10.0.0.0/24
subnet_cidr      = "10.100.0.0/20"   # 4,096 IPs for nodes (10.100.0.0 - 10.100.15.255)
pods_cidr        = "10.104.0.0/14"   # 262,144 IPs for pods (10.104.0.0 - 10.107.255.255)
services_cidr    = "10.108.0.0/20"   # 4,096 IPs for services (10.108.0.0 - 10.108.15.255)
master_ipv4_cidr = "172.16.0.0/28"   # GKE master nodes

# Cloud NAT Configuration
enable_cloud_nat     = true
nat_min_ports_per_vm = 64
nat_enable_logging   = true
nat_log_filter       = "ERRORS_ONLY"

# Firewall Configuration
enable_default_firewall_rules = true

# VPC Flow Logs - Reduced sampling for dev
enable_flow_logs     = true
flow_logs_sampling   = 0.1
flow_logs_interval   = "INTERVAL_10_MIN"

labels = {
  owner       = "infrastructure-team"
  cost_center = "development"
}
