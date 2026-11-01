variable "assume_role_arn" {
  description = "ARN of the IAM role to assume for cross-account access"
  type        = string
  default     = ""
}

variable "region" {
  description = "AWS region for networking resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_region" {
  description = "AWS region for deployment (used by provider)"
  type        = string
  default     = "us-east-1"
}

# Environment configuration
variable "environment" {
  description = "Environment name (e.g., dev, stg, live)"
  type        = string
  default     = "dev"
}

variable "vpc_name" {
  description = "Name of the VPC to use"
  type        = string
}

# Database configuration
variable "postgres_version" {
  description = "PostgreSQL version"
  type        = string
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
}

variable "database_name" {
  description = "Name of the database to create"
  type        = string
}

variable "db_username" {
  description = "Master username for the database"
  type        = string
}

# Storage configuration
variable "allocated_storage" {
  description = "Initial allocated storage in GB"
  type        = number
}

variable "max_allocated_storage" {
  description = "Maximum allocated storage for autoscaling in GB"
  type        = number
}

variable "storage_type" {
  description = "Storage type (gp2, gp3, io1)"
  type        = string
  default     = "gp3"
}

# Parameter group configuration
variable "parameter_group_family" {
  description = "Parameter group family"
  type        = string
}

variable "log_min_duration_statement" {
  description = "Minimum duration to log statements (ms)"
  type        = string
  default     = "1000"
}

variable "max_connections" {
  description = "Maximum number of connections"
  type        = string
  default     = "100"
}

# Backup configuration
variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
}

variable "backup_window" {
  description = "Backup window (UTC)"
  type        = string
  default     = "03:00-04:00"
}

# Maintenance configuration
variable "maintenance_window" {
  description = "Maintenance window (UTC)"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "auto_minor_version_upgrade" {
  description = "Enable auto minor version upgrades"
  type        = bool
  default     = true
}

# Monitoring configuration
variable "monitoring_interval" {
  description = "Enhanced monitoring interval (0, 1, 5, 10, 15, 30, 60)"
  type        = number
  default     = 60

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "Monitoring interval must be 0, 1, 5, 10, 15, 30, or 60."
  }
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

# Security configuration
variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot when destroying"
  type        = bool
  default     = false
}

# Additional storage configuration
variable "storage_iops" {
  description = "Provisioned IOPS for storage"
  type        = number
  default     = null
}

variable "storage_throughput" {
  description = "Storage throughput in MB/s"
  type        = number
  default     = null
}

variable "shared_preload_libraries" {
  description = "Shared preload libraries for PostgreSQL"
  type        = string
  default     = ""
}

# Additional backup configuration
variable "copy_tags_to_snapshot" {
  description = "Copy tags to snapshots"
  type        = bool
  default     = false
}

variable "delete_automated_backups" {
  description = "Delete automated backups when instance is deleted"
  type        = bool
  default     = true
}

variable "final_snapshot_identifier" {
  description = "Final snapshot identifier before deletion"
  type        = string
  default     = null
}


variable "performance_insights_retention_period" {
  description = "Performance Insights retention period in days"
  type        = number
  default     = 7
}

# High availability
variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

# Additional security configuration
variable "publicly_accessible" {
  description = "Make the database publicly accessible"
  type        = bool
  default     = false
}

variable "storage_encrypted" {
  description = "Enable storage encryption"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
  default     = "alias/aws/rds"
}

# Tags
variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Scheduler configuration
variable "enable_scheduler" {
  description = "Enable scheduler tags for automated start/stop (only for dev and stg environments)"
  type        = bool
  default     = false
}