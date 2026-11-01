# RDS Instance Information
output "rds_instance_id" {
  description = "RDS instance ID"
  value       = module.postgres_rds.id
}

output "rds_instance_arn" {
  description = "RDS instance ARN"
  value       = module.postgres_rds.arn
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.postgres_rds.endpoint
}

output "rds_address" {
  description = "RDS instance address (hostname)"
  value       = module.postgres_rds.address
}

output "rds_port" {
  description = "RDS instance port"
  value       = module.postgres_rds.port
}

output "database_name" {
  description = "Database name"
  value       = module.postgres_rds.database_name
}

output "database_username" {
  description = "Database master username"
  value       = module.postgres_rds.username
  sensitive   = true
}

# Connection Information
output "connection_string" {
  description = "Database connection string (password from SSM)"
  value       = "postgresql://${module.postgres_rds.username}:${aws_ssm_parameter.postgres_password.name}@${module.postgres_rds.endpoint}/${module.postgres_rds.database_name}"
  sensitive   = true
}

output "jdbc_connection_string" {
  description = "JDBC connection string"
  value       = module.postgres_rds.jdbc_connection_string
}

# Security
output "security_group_id" {
  description = "Security group ID for RDS instance"
  value       = module.postgres_rds.security_group_id
}

# SSM Parameters
output "ssm_password_parameter" {
  description = "SSM parameter name for database password"
  value       = aws_ssm_parameter.postgres_password.name
}

output "ssm_endpoint_parameter" {
  description = "SSM parameter name for database endpoint"
  value       = aws_ssm_parameter.postgres_endpoint.name
}

output "ssm_connection_parameter" {
  description = "SSM parameter name for database connection string"
  value       = aws_ssm_parameter.postgres_connection_string.name
}

# Network Information
output "subnet_group_name" {
  description = "DB subnet group name"
  value       = module.postgres_rds.subnet_group_name
}

output "availability_zone" {
  description = "RDS instance availability zone"
  value       = module.postgres_rds.availability_zone
}

# Status
output "rds_status" {
  description = "RDS instance status"
  value       = module.postgres_rds.status
}