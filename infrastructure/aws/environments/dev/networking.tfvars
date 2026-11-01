# Development Environment Configuration - Networking
# Cost-optimized settings for development workloads

region      = "us-east-1"
environment = "dev"

# VPC Configuration
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# Subnet Configuration
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]

# NAT Gateway Configuration - Cost optimized for dev
enable_nat_gateway = true
single_nat_gateway = true # Single NAT to reduce costs

# DNS Configuration
enable_dns_hostnames = true
enable_dns_support   = true

# VPC Flow Logs Configuration - Disabled for cost optimization
enable_vpc_flow_logs    = false  # Optimized: Was true, disabled to save $3/month
vpc_flow_logs_retention = 3 # Short retention for dev

# Additional Tags
additional_tags = {
  Owner       = "infrastructure-team"
  CostCenter  = "development"
  Environment = "dev"
  Purpose     = "core-networking"
  Backup      = "none"
}