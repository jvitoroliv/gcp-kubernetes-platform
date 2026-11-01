# Production Environment Configuration - PostgreSQL RDS
# Production-grade high availability and performance settings

environment = "live"
vpc_name    = "project-live-vpc"
region      = "sa-east-1"

# Database configuration
postgres_version = "14.17"        # Compatível com migração de PG12
instance_class   = "db.t3.xlarge" # Production performance instance
database_name    = "nakama"       # Database principal
db_username      = "postgres"

# Storage configuration - Production sizing
allocated_storage     = 70  # 100 GB initial
max_allocated_storage = 300 # Auto-scaling up to 1TB
storage_type          = "gp3"

# Performance configuration
storage_iops       = 3000 # Provisioned IOPS for performance
storage_throughput = 125  # MB/s throughput

# Parameter group configuration
parameter_group_family     = "postgres14"
log_min_duration_statement = "100" # Log slower queries in production
max_connections            = "500" # Higher connection limit for production
shared_preload_libraries   = "pg_stat_statements,pg_hint_plan"

# Backup configuration - Production settings
backup_retention_period  = 30            # 30 days retention
backup_window            = "03:00-04:00" # During low traffic
copy_tags_to_snapshot    = true
delete_automated_backups = false

# Maintenance configuration
maintenance_window         = "sun:04:00-sun:06:00"
auto_minor_version_upgrade = true

# Monitoring configuration - Full monitoring for production
monitoring_interval                   = 60   # Enhanced monitoring every minute
performance_insights_enabled          = true # Enable performance insights
performance_insights_retention_period = 7    # 7 days retention

# High Availability - Multi-AZ for production
multi_az = true

# Security configuration
deletion_protection       = true  # Prevent accidental deletion
skip_final_snapshot       = false # Always create final snapshot
final_snapshot_identifier = "project-live-postgres-final-snapshot"

# Encryption
storage_encrypted = true
kms_key_id        = "alias/aws/rds"

# Network security
publicly_accessible = false

# Additional Tags
tags = {
  purpose            = "database"
  backup             = "automated"
  monitoringtier     = "critical"
  dataclassification = "internal"
  compliance         = "required"
  disasterrecovery   = "tier1"
}