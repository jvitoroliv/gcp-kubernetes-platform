output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_arn" {
  description = "ARN of the VPC"
  value       = module.vpc.vpc_arn
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.cidr_block
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = module.internet_gateway.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.public_subnets.subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.private_subnets.subnet_ids
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets"
  value       = var.public_subnet_cidrs
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets"
  value       = var.private_subnet_cidrs
}

output "availability_zones" {
  description = "Availability zones used by subnets"
  value       = var.availability_zones
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = var.enable_nat_gateway ? [for nat in module.nat_gateways : nat.id] : []
}

output "nat_gateway_public_ips" {
  description = "Public IP addresses of the NAT Gateways"
  value       = var.enable_nat_gateway ? [for eip in aws_eip.nat_gateway : eip.public_ip] : []
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = module.public_route_table.route_table_id
}

output "private_route_table_ids" {
  description = "IDs of the private route tables"
  value       = [for rt in module.private_route_tables : rt.route_table_id]
}

output "vpc_flow_logs_log_group_name" {
  description = "Name of the VPC Flow Logs CloudWatch log group"
  value       = var.enable_vpc_flow_logs ? module.vpc_flow_logs[0].name : null
}

output "vpc_flow_logs_iam_role_arn" {
  description = "ARN of the VPC Flow Logs IAM role"
  value       = var.enable_vpc_flow_logs ? module.flow_logs_role[0].arn : null
}

output "network_summary" {
  description = "Summary of networking configuration"
  value = {
    vpc_id             = module.vpc.vpc_id
    vpc_cidr           = module.vpc.cidr_block
    environment        = var.environment
    availability_zones = var.availability_zones
    public_subnets = {
      count = length(var.public_subnet_cidrs)
      ids   = module.public_subnets.subnet_ids
      cidrs = var.public_subnet_cidrs
    }
    private_subnets = {
      count = length(var.private_subnet_cidrs)
      ids   = module.private_subnets.subnet_ids
      cidrs = var.private_subnet_cidrs
    }
    nat_gateways = {
      enabled    = var.enable_nat_gateway
      single_nat = var.single_nat_gateway
      count      = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnet_cidrs)) : 0
      public_ips = var.enable_nat_gateway ? [for eip in aws_eip.nat_gateway : eip.public_ip] : []
    }
    vpc_flow_logs = {
      enabled        = var.enable_vpc_flow_logs
      retention_days = var.vpc_flow_logs_retention
    }
  }
}
