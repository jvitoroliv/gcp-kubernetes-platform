# =============================================================================
# STG ENVIRONMENT - NETWORKING STACK
# NOTE: Stg has SAME configuration as Prd for parity testing
# =============================================================================

project_id  = "project-nonprod-env"
environment = "stg"
region      = "us-east1"

# VPC Configuration
vpc_routing_mode = "REGIONAL"

# Subnet Configuration - SAME AS PRD
subnet_cidr      = "10.1.0.0/20"     # 4,096 IPs for nodes
pods_cidr        = "10.32.0.0/14"    # 262,144 IPs for pods
services_cidr    = "10.36.0.0/20"    # 4,096 IPs for services
master_ipv4_cidr = "172.16.1.0/28"   # GKE master nodes

# Cloud NAT Configuration - SAME AS PRD
enable_cloud_nat     = true
nat_min_ports_per_vm = 2048 # Higher for production workloads
nat_enable_logging   = true
nat_log_filter       = "ERRORS_ONLY"

# Firewall Configuration
enable_default_firewall_rules = true

# VPC Flow Logs - SAME AS PRD
enable_flow_logs     = true
flow_logs_sampling   = 0.5
flow_logs_interval   = "INTERVAL_5_SEC"

labels = {
  owner       = "infrastructure-team"
  cost_center = "stg"
}
