# Staging Environment Configuration - PostgreSQL RDS
# OPTIMIZED VERSION - OPTION B (AGGRESSIVE - STORAGE ONLY)
#
# Changes made:
# - allocated_storage: 50 GB → 15 GB (saving $6.44/month)
# - max_allocated_storage: 150 GB → 50 GB (preserved auto-scaling)
# - instance_class: NO CHANGE (kept db.t3.medium due to CPU spike concern)
# - storage_iops: 3000 → null (use gp3 baseline - included)
# - storage_throughput: 125 → null (use gp3 baseline - included)
#
# Total Savings: $6.44/month ($77.28/year)
#
# Rationale: Conservative approach due to:
#   - High connection count (151 avg, 263 max) still under investigation
#   - CPU spike detected (87.32% max) requires larger instance
#   - Lower risk profile for production-like staging environment
#
# File: /Repos/gameplatform-shared-infrastructure/environments/stg/postgres.tfvars

environment = "stg"
vpc_name    = "project-stg-vpc"
region      = "us-east-1"

# Database configuration
postgres_version = "14.17"
instance_class   = "db.t3.medium" # NO CHANGE - Kept due to CPU spike and connection concerns
database_name    = "nakama"
db_username      = "postgres"

# Storage configuration - OPTIMIZED
allocated_storage     = 15  # CHANGED: Was 50 GB, now 15 GB (using 5.08 GB currently)
max_allocated_storage = 50  # CHANGED: Was 150 GB, now 50 GB (sufficient headroom)
storage_type          = "gp3"

# Performance configuration - Use gp3 baseline
# gp3 includes 3000 IOPS and 125 MB/s baseline at no extra cost
storage_iops       = null # CHANGED: Was 3000 (now included in gp3 baseline)
storage_throughput = null # CHANGED: Was 125 (now included in gp3 baseline)

# Parameter group configuration
parameter_group_family     = "postgres14"
log_min_duration_statement = "100"
max_connections            = "200" # NO CHANGE - Kept at 200 for db.t3.medium
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
  optimized          = "2025-11-05"
  optimization_plan  = "option-b-aggressive-storage-only"
}

# Scheduler configuration (automated start/stop)
enable_scheduler = false # Set to true to enable automated shutdown/startup
