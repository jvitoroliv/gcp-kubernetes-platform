output "atlantis_url" {
  description = "URL of the Atlantis server"
  value       = "https://${var.atlantis_domain}"
}

output "atlantis_service_name" {
  description = "Name of the ECS service for Atlantis"
  value       = module.atlantis_service.name
}

output "atlantis_task_definition_arn" {
  description = "ARN of the Atlantis task definition"
  value       = module.atlantis_task_definition.arn
}

output "atlantis_target_group_arn" {
  description = "ARN of the Atlantis target group"
  value       = module.atlantis_target_group.arn
}

output "atlantis_security_group_id" {
  description = "ID of the Atlantis security group"
  value       = module.atlantis_security_group.id
}

output "atlantis_task_role_arn" {
  description = "ARN of the Atlantis task IAM role"
  value       = module.atlantis_task_role.arn
}

output "atlantis_execution_role_arn" {
  description = "ARN of the Atlantis execution IAM role"
  value       = module.atlantis_execution_role.arn
}

output "atlantis_log_group_name" {
  description = "Name of the Atlantis CloudWatch log group"
  value       = module.atlantis_logs.name
}

output "github_token_parameter_arn" {
  description = "ARN of the GitHub token SSM parameter"
  value       = module.github_token_parameter.arn
  sensitive   = true
}

output "github_webhook_secret_parameter_arn" {
  description = "ARN of the GitHub webhook secret SSM parameter"
  value       = module.github_webhook_secret_parameter.arn
  sensitive   = true
}

output "atlantis_dns_record_fqdn" {
  description = "FQDN of the Atlantis DNS record"
  value       = module.atlantis_dns_record.fqdn
}

output "webhook_url" {
  description = "GitHub webhook URL for Atlantis"
  value       = "https://${var.atlantis_domain}/events"
}

output "deployment_summary" {
  description = "Summary of Atlantis deployment"
  value = {
    atlantis_url = "https://${var.atlantis_domain}"
    webhook_url  = "https://${var.atlantis_domain}/events"
    environment  = var.environment
    ecs_service  = module.atlantis_service.name
    cluster_name = data.aws_ecs_cluster.shared.cluster_name
    log_group    = module.atlantis_logs.name

    configuration = {
      cpu           = var.atlantis_cpu
      memory        = var.atlantis_memory
      desired_count = var.atlantis_desired_count
      auto_scaling  = var.enable_auto_scaling
      min_capacity  = var.enable_auto_scaling ? var.min_capacity : null
      max_capacity  = var.enable_auto_scaling ? var.max_capacity : null
    }

    github = {
      owner              = var.github_owner
      repo               = var.github_repo
      webhook_configured = false # Will need manual configuration
    }
  }
}

output "setup_instructions" {
  description = "Instructions for completing Atlantis setup"
  value = {
    step_1 = "Verify Atlantis is running: curl -I https://${var.atlantis_domain}/healthz"
    step_2 = "Configure GitHub webhook: URL=https://${var.atlantis_domain}/events, Secret=<from SSM parameter>"
    step_3 = "Test with a PR that modifies Terraform files"
    step_4 = "Check logs: aws logs tail ${module.atlantis_logs.name} --follow"
    step_5 = "View ECS service: aws ecs describe-services --cluster ${data.aws_ecs_cluster.shared.cluster_name} --services ${module.atlantis_service.name}"

    troubleshooting = {
      health_check    = "https://${var.atlantis_domain}/healthz"
      logs_command    = "aws logs tail ${module.atlantis_logs.name} --follow"
      restart_command = "aws ecs update-service --cluster ${data.aws_ecs_cluster.shared.cluster_name} --service ${module.atlantis_service.name} --force-new-deployment"
    }
  }
}