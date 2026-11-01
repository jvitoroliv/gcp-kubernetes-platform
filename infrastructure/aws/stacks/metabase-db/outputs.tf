output "cluster_id" {
  description = "The RDS Cluster Identifier"
  value       = module.metabase_serverless_db.cluster_id
}

output "cluster_arn" {
  description = "Amazon Resource Name (ARN) of the cluster"
  value       = module.metabase_serverless_db.cluster_arn
}

output "cluster_endpoint" {
  description = "The cluster writer endpoint"
  value       = module.metabase_serverless_db.cluster_endpoint
}

output "cluster_reader_endpoint" {
  description = "The cluster reader endpoint"
  value       = module.metabase_serverless_db.cluster_reader_endpoint
}

output "database_name" {
  description = "The database name"
  value       = module.metabase_serverless_db.cluster_database_name
}

output "master_username" {
  description = "The master username for the database"
  value       = module.metabase_serverless_db.cluster_master_username
  sensitive   = true
}

output "port" {
  description = "The database port"
  value       = module.metabase_serverless_db.cluster_port
}

output "secret_arn" {
  description = "The ARN of the secret containing database credentials"
  value       = module.db_password_secret.arn
}

output "secret_name" {
  description = "The name of the secret containing database credentials"
  value       = module.db_password_secret.name
}

output "instance_endpoints" {
  description = "The connection endpoints for each RDS instance"
  value       = module.metabase_serverless_db.instance_endpoints
}

output "instance_ids" {
  description = "The instance identifiers"
  value       = module.metabase_serverless_db.instance_ids
}

output "security_group_id" {
  description = "The security group ID used for the database"
  value       = data.aws_security_group.rds.id
}

output "subnet_ids" {
  description = "The subnet IDs used for the database"
  value       = data.aws_subnets.private.ids
}

output "log_group_name" {
  description = "The name of the CloudWatch log group for RDS logs"
  value       = module.rds_log_group.name
}

output "connection_string" {
  description = "PostgreSQL connection string (without password)"
  value       = "postgresql://${var.master_username}@${module.metabase_serverless_db.cluster_endpoint}:${module.metabase_serverless_db.cluster_port}/${var.database_name}"
}

output "jdbc_connection_string" {
  description = "JDBC connection string for Metabase (without password)"
  value       = "jdbc:postgresql://${module.metabase_serverless_db.cluster_endpoint}:${module.metabase_serverless_db.cluster_port}/${var.database_name}"
}