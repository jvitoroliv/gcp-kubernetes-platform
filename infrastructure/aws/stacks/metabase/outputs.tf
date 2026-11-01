output "autoscaling_group_id" {
  description = "The Auto Scaling Group ID"
  value       = module.metabase_autoscaling_group.id
}

output "autoscaling_group_name" {
  description = "The Auto Scaling Group name"
  value       = module.metabase_autoscaling_group.name
}

output "autoscaling_group_arn" {
  description = "The ARN for the Auto Scaling Group"
  value       = module.metabase_autoscaling_group.arn
}

output "launch_template_id" {
  description = "The ID of the launch template"
  value       = module.metabase_launch_template.id
}

output "launch_template_latest_version" {
  description = "The latest version of the launch template"
  value       = module.metabase_launch_template.latest_version
}

output "target_group_arn" {
  description = "The ARN of the target group"
  value       = module.metabase_target_group.arn
}

output "security_group_id" {
  description = "The ID of the security group"
  value       = module.metabase_security_group.id
}

output "instance_role_arn" {
  description = "The ARN of the IAM role for instances"
  value       = module.metabase_instance_role.arn
}

output "instance_profile_arn" {
  description = "The ARN of the IAM instance profile"
  value       = aws_iam_instance_profile.metabase.arn
}

output "dns_name" {
  description = "The DNS name for Metabase"
  value       = "ani-metrics.${var.domain_name}"
}

output "url" {
  description = "The URL to access Metabase"
  value       = "https://ani-metrics.${var.domain_name}"
}

output "log_group_name" {
  description = "The name of the CloudWatch log group"
  value       = module.metabase_log_group.name
}