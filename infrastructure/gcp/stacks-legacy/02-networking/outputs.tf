output "vpc_name" {
  description = "Name of the VPC"
  value       = module.vpc.name
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.id
}

output "vpc_self_link" {
  description = "Self link of the VPC"
  value       = module.vpc.self_link
}

output "subnet_name" {
  description = "Name of the subnet"
  value       = module.subnet.name
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = module.subnet.id
}

output "subnet_self_link" {
  description = "Self link of the subnet"
  value       = module.subnet.self_link
}

output "subnet_cidr" {
  description = "CIDR range of the subnet"
  value       = module.subnet.ip_cidr_range
}

output "router_name" {
  description = "Name of the Cloud Router"
  value       = var.create_nat ? module.cloud_router[0].name : null
}

output "nat_name" {
  description = "Name of the Cloud NAT"
  value       = var.create_nat ? module.cloud_nat[0].name : null
}
