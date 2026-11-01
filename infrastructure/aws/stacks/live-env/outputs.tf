output "cluster_id" {
  description = "The ECS cluster ID"
  value       = module.ecs_cluster.id
}

output "cluster_name" {
  description = "The ECS cluster name"
  value       = module.ecs_cluster.name
}

output "cluster_arn" {
  description = "The ECS cluster ARN"
  value       = module.ecs_cluster.arn
}

output "service_discovery_namespace_id" {
  description = "The service discovery namespace ID"
  value       = module.service_discovery_namespace.id
}

output "service_urls" {
  description = "URLs for all services"
  value = {
    nakama        = "https://api.${var.domain_name}"
    lobby         = "https://app.${var.domain_name}"
    afs           = "https://afs.${var.domain_name}"
    ahsat         = "https://ahsat.${var.domain_name}"
    aes           = "https://aes.${var.domain_name}"
    lobby_backend = "https://lobby-backend.${var.domain_name}"
  }
}

output "database_endpoint" {
  description = "RDS database endpoint"
  value       = data.aws_db_instance.shared_rds.endpoint
}

output "vpc_id" {
  description = "VPC ID"
  value       = data.aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = data.aws_subnets.private.ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = data.aws_subnets.public.ids
}

output "security_group_id" {
  description = "Security group ID for services"
  value       = module.security_group.id
}

output "task_role_arn" {
  description = "ECS task role ARN"
  value       = module.ecs_task_role.arn
}

output "execution_role_arn" {
  description = "ECS execution role ARN"
  value       = module.ecs_execution_role.arn
}