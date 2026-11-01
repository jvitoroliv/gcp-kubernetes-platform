output "cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs_cluster.name
}

output "cluster_arn" {
  description = "ECS cluster ARN"
  value       = module.ecs_cluster.arn
}

output "runners_summary" {
  description = "Summary of runners/cluster configuration"
  value = {
    cluster_name       = module.ecs_cluster.name
    capacity_providers = var.capacity_providers
    environment        = var.environment
  }
}
