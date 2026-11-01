output "server_url" {
  description = "URL for the server environment"
  value       = "https://nakama.${var.domain_name}"
}

output "lobby_url" {
  description = "URL for the lobby environment"
  value       = "https://lobby.${var.domain_name}"
}

output "nakama_service_name" {
  description = "Name of the server ECS service"
  value       = module.nakama_service.name
}

output "afs_service_name" {
  description = "Name of the server ECS service"
  value       = module.afs_service.name
}

output "ahsat_service_name" {
  description = "Name of the server ECS service"
  value       = module.ahsat_service.name
}

output "lobby_service_name" {
  description = "Name of the lobby ECS service"
  value       = module.lobby_service.name
}

output "nakama_task_definition_arn" {
  description = "ARN of the server task definition"
  value       = module.nakama_task_definition.arn
}

output "afs_task_definition_arn" {
  description = "ARN of the server task definition"
  value       = module.afs_task_definition.arn
}

output "ahsat_task_definition_arn" {
  description = "ARN of the server task definition"
  value       = module.ahsat_task_definition.arn
}

output "lobby_task_definition_arn" {
  description = "ARN of the lobby task definition"
  value       = module.lobby_task_definition.arn
}

output "security_group_id" {
  description = "ID of the environment security group"
  value       = module.security_group.id
}

output "server_target_group_arn" {
  description = "ARN of the server ALB target group"
  value       = module.server_target_group.arn
}

output "lobby_target_group_arn" {
  description = "ARN of the lobby ALB target group"
  value       = module.lobby_target_group.arn
}

output "aes_task_definition_arn" {
  description = "ARN of the AES ECS task definition"
  value       = module.aes_task_definition.arn
}

output "aes_target_group_arn" {
  description = "ARN of the AES ALB target group"
  value       = module.aes_target_group.arn
}

output "lobby_backend_task_definition_arn" {
  description = "ARN of the Lobby Backend ECS task definition"
  value       = module.lobby_backend_task_definition.arn
}

output "lobby_backend_target_group_arn" {
  description = "ARN of the Lobby Backend ALB target group"
  value       = module.lobby_backend_target_group.arn
}

output "ses_smtp_server" {
  description = "SES SMTP server endpoint"
  value       = module.ses_configuration.smtp_server
}

output "environment_info" {
  description = "Summary information about the environment"
  value = {
    pr_number         = var.pr_number
    git_sha           = var.git_sha
    server_url        = "https://nakama.${var.domain_name}"
    afs_url           = "https://afs.${var.domain_name}"
    ahsat_url         = "https://ahsat.${var.domain_name}"
    lobby_url         = "https://lobby.${var.domain_name}"
    aes_url           = "https://aes.${var.domain_name}"
    lobby_backend_url = "https://lobby-backend.${var.domain_name}"
    created_at        = timestamp()
    environment       = var.environment
  }
}