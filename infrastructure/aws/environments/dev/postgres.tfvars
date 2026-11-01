# Development Environment Configuration - PostgreSQL RDS
# Cost-optimized settings for development workloads

environment = "dev"
vpc_name    = "project-dev-vpc"

# Database configuration
postgres_version = "14.17"       # Compatível com migração de PG12
instance_class   = "db.t3.micro" # Cost-optimized for dev
database_name    = "nakama"      # Database principal (não gameplatform)
db_username      = "postgres"

# Storage configuration - minimal for dev
allocated_storage     = 10  # Optimized: Was 20 GB, reduced to 10 GB (using only 3.15 GB)
max_allocated_storage = 100
storage_type          = "gp3"

# Parameter group configuration
parameter_group_family     = "postgres14"
log_min_duration_statement = "1000"
max_connections            = "100"

# Backup configuration - minimal for dev
backup_retention_period = 7
backup_window           = "03:00-04:00"

# Maintenance configuration
maintenance_window         = "sun:04:00-sun:05:00"
auto_minor_version_upgrade = true

# Monitoring configuration - simplified for dev
monitoring_interval          = 0     # Desabilita enhanced monitoring
performance_insights_enabled = false # Desabilita performance insights

# Security configuration
deletion_protection = false # Allow deletion in dev
skip_final_snapshot = true  # Skip snapshot in dev for faster destruction

# Additional Tags
tags = {
  Owner       = "infrastructure-team"
  CostCenter  = "development"
  Environment = "dev"
  Purpose     = "database"
  Backup      = "automated"
}

# Scheduler configuration (automated start/stop)
enable_scheduler = false # Set to true to enable automated shutdown/startup