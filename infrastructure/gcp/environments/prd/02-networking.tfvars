# =============================================================================
# PRD (PRODUCTION) ENVIRONMENT - NETWORKING STACK
# =============================================================================

project_id  = "project-prd-env"
environment = "prd"
region      = "southamerica-east1"

# VPC Configuration
vpc_routing_mode = "REGIONAL"

# Subnet Configuration
subnet_cidr      = "10.2.0.0/20"     # 4,096 IPs for nodes
pods_cidr        = "10.48.0.0/14"    # 262,144 IPs for pods
services_cidr    = "10.52.0.0/20"    # 4,096 IPs for services
master_ipv4_cidr = "172.16.2.0/28"   # GKE master nodes

# Cloud NAT Configuration - Production grade
enable_cloud_nat     = true
nat_min_ports_per_vm = 2048 # Higher for production workloads
nat_enable_logging   = true
nat_log_filter       = "ERRORS_ONLY"

# Firewall Configuration
enable_default_firewall_rules = true

# VPC Flow Logs - Full sampling for production
enable_flow_logs     = true
flow_logs_sampling   = 0.5
flow_logs_interval   = "INTERVAL_5_SEC"

labels = {
  owner              = "infrastructure-team"
  cost_center        = "production"
  data_classification = "confidential"
  compliance         = "required"
}
