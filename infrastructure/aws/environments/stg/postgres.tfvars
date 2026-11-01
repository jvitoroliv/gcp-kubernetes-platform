# Staging Environment Configuration - PostgreSQL RDS
# Staging settings with production-like configuration

environment = "stg"
vpc_name    = "project-stg-vpc"
region      = "us-east-1"

# Database configuration
postgres_version = "14.17"
instance_class   = "db.t3.small"  # Optimized: Downgraded from db.t3.medium (4GB → 2GB RAM), saves $16.42/month
database_name    = "nakama"
db_username      = "postgres"

# Storage configuration - Optimized for staging
allocated_storage     = 15   # Optimized: Reduced from 50 GB to 15 GB (using only 5.08 GB), saves $6.44/month
max_allocated_storage = 50   # Optimized: Reduced from 150 GB to 50 GB (sufficient headroom)
storage_type          = "gp3"

# Performance configuration - Use gp3 baseline (included at no extra cost)
storage_iops       = null  # Optimized: Removed provisioned IOPS, use gp3 baseline 3000 IOPS (included)
storage_throughput = null  # Optimized: Removed provisioned throughput, use gp3 baseline 125 MB/s (included)

# Parameter group configuration
parameter_group_family     = "postgres14"
log_min_duration_statement = "100"
max_connections            = "100"  # Optimized: Reduced from 200 to 100 (appropriate for db.t3.small)
shared_preload_libraries   = "pg_stat_statements,pg_hint_plan"

# Backup configuration - Staging settings
backup_retention_period  = 7 # 7 days retention
backup_window            = "03:00-04:00"
copy_tags_to_snapshot    = true
delete_automated_backups = false

# Maintenance configuration
maintenance_window         = "sun:04:00-sun:06:00"
auto_minor_version_upgrade = true

# Monitoring configuration
monitoring_interval                   = 60
performance_insights_enabled          = true
performance_insights_retention_period = 7

# High Availability - Single AZ for staging
multi_az = false

# Security configuration
deletion_protection       = false # Allow deletion in staging
skip_final_snapshot       = false
final_snapshot_identifier = "project-stg-postgres-final-snapshot"

# Encryption
storage_encrypted = true
kms_key_id        = "alias/aws/rds"

# Network security
publicly_accessible = false

# Additional Tags
tags = {
  purpose            = "database"
  backup             = "automated"
  monitoringtier     = "high"
  dataclassification = "internal"
  compliance         = "testing"
}

# Scheduler configuration (automated start/stop)
enable_scheduler = false # Set to true to enable automated shutdown/startup
