# Staging Environment Configuration - Networking
# Staging high availability settings

region      = "us-east-1"
environment = "stg"

# VPC Configuration
vpc_cidr           = "10.1.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# Subnet Configuration
public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
private_subnet_cidrs = ["10.1.11.0/24", "10.1.12.0/24", "10.1.13.0/24"]

# NAT Gateway Configuration - Optimized for cost
enable_nat_gateway = true
single_nat_gateway = true  # Optimized: Changed from false, reduces from 3 to 1 NAT Gateway, saves $64.80/month

# DNS Configuration
enable_dns_hostnames = true
enable_dns_support   = true

# VPC Flow Logs Configuration
enable_vpc_flow_logs    = true
vpc_flow_logs_retention = 7  # Optimized: Reduced from 14 to 7 days for staging, saves $2.50/month

# Additional Tags
additional_tags = {
  Owner              = "infrastructure-team"
  CostCenter         = "engineering"
  Environment        = "staging"
  Purpose            = "core-networking"
  Backup             = "weekly"
  MonitoringTier     = "high"
  DataClassification = "internal"
  Compliance         = "testing"
}
