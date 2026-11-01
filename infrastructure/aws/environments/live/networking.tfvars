# Production Environment Configuration - Networking
# Production-grade high availability settings

region      = "sa-east-1"
environment = "live"

# VPC Configuration
vpc_cidr           = "10.1.0.0/16" # Different CIDR from dev
availability_zones = ["sa-east-1a", "sa-east-1b", "sa-east-1c"]

# Subnet Configuration
public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
private_subnet_cidrs = ["10.1.11.0/24", "10.1.12.0/24", "10.1.13.0/24"]

# NAT Gateway Configuration - High availability for production
enable_nat_gateway = true
single_nat_gateway = false # Multiple NAT gateways for HA

# DNS Configuration
enable_dns_hostnames = true
enable_dns_support   = true

# VPC Flow Logs Configuration
enable_vpc_flow_logs    = true
vpc_flow_logs_retention = 90 # Extended retention for production

# Additional Tags
additional_tags = {
  Owner              = "infrastructure-team"
  CostCenter         = "production"
  Environment        = "live"
  Purpose            = "core-networking"
  Backup             = "daily"
  MonitoringTier     = "critical"
  DataClassification = "internal"
  Compliance         = "required"
  DisasterRecovery   = "tier1"
}