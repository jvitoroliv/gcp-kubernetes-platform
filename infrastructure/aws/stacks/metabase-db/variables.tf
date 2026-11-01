variable "region" {
  description = "AWS region for database resources"
  type        = string
  default     = "sa-east-1"
}

variable "environment" {
  description = "Environment name (live)"
  type        = string
  default     = "live"
}

variable "engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "16.6"
}

variable "database_name" {
  description = "Name of the database to create"
  type        = string
  default     = "metabase"
}

variable "master_username" {
  description = "Master username for the database"
  type        = string
  default     = "postgres"
}

variable "database_password" {
  description = "Master password for the database (if empty, will generate random)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "serverless_min_capacity" {
  description = "Minimum capacity for Aurora Serverless v2 (in ACUs)"
  type        = number
  default     = 1
}

variable "serverless_max_capacity" {
  description = "Maximum capacity for Aurora Serverless v2 (in ACUs)"
  type        = number
  default     = 64
}

variable "instance_count" {
  description = "Number of instances in the cluster (1 for single writer)"
  type        = number
  default     = 1
}

variable "backup_retention_period" {
  description = "Days to retain backups"
  type        = number
  default     = 7
}

variable "preferred_backup_window" {
  description = "Daily time range for automated backups"
  type        = string
  default     = "03:00-04:00"
}

variable "preferred_maintenance_window" {
  description = "Weekly time range for system maintenance"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "skip_final_snapshot" {
  description = "Skip final DB snapshot on deletion"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Apply changes immediately"
  type        = bool
  default     = false
}

variable "allow_major_version_upgrade" {
  description = "Allow major version upgrades"
  type        = bool
  default     = false
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval in seconds (0 to disable)"
  type        = number
  default     = 0
}

variable "log_retention_days" {
  description = "CloudWatch logs retention in days"
  type        = number
  default     = 30
}

variable "cpu_alarm_threshold" {
  description = "CPU utilization threshold for CloudWatch alarm"
  type        = number
  default     = 80
}

variable "connections_alarm_threshold" {
  description = "Database connections threshold for CloudWatch alarm"
  type        = number
  default     = 80
}

variable "capacity_alarm_threshold" {
  description = "Serverless capacity units threshold for CloudWatch alarm"
  type        = number
  default     = 50
}

variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "rds-security-group-name" {
  description = "Name of the existing RDS security group to attach to the cluster"
  type        = string
}