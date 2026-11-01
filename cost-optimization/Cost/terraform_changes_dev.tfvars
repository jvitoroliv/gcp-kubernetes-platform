# Development Environment Configuration - PostgreSQL RDS
# OPTIMIZED VERSION - Cost reduction changes
#
# Changes made:
# - allocated_storage: 20 GB → 10 GB (saving $1.84/month)
# - Rationale: Currently using only 3.15 GB (15.8%)
# - Safety: Provides 3x headroom, auto-scaling to 100 GB preserved
#
# File: /Repos/gameplatform-shared-infrastructure/environments/dev/postgres.tfvars

environment = "dev"
vpc_name    = "project-dev-vpc"

# Database configuration
postgres_version = "14.17"       # Compatible with PG12 migration
instance_class   = "db.t3.micro" # NO CHANGE - Already minimum size
database_name    = "nakama"      # Main database
db_username      = "postgres"

# Storage configuration - OPTIMIZED for dev
allocated_storage     = 10  # CHANGED: Was 20 GB, now 10 GB (using 3.15 GB currently)
max_allocated_storage = 100 # NO CHANGE - Preserved for auto-scaling
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
monitoring_interval          = 0     # NO CHANGE - Enhanced monitoring disabled
performance_insights_enabled = false # NO CHANGE - Performance insights disabled

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
