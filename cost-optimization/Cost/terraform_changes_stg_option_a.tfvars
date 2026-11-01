# Staging Environment Configuration - PostgreSQL RDS
# OPTIMIZED VERSION - OPTION A (CONSERVATIVE - RECOMMENDED)
#
# Changes made:
# - instance_class: db.t3.medium → db.t3.small (saving $16.42/month)
# - allocated_storage: 50 GB → 15 GB (saving $6.44/month)
# - max_allocated_storage: 150 GB → 50 GB (preserved auto-scaling)
# - max_connections: 200 → 100 (reduced with instance size)
# - storage_iops: 3000 → null (use gp3 baseline - included)
# - storage_throughput: 125 → null (use gp3 baseline - included)
#
# Total Savings: $22.86/month ($274.32/year)
#
# ⚠️ CRITICAL: Apply ONLY after connection investigation complete
# ⚠️ MONITOR: CPU, memory, connections closely for 2 weeks post-change
# ⚠️ ROLLBACK: Restore to db.t3.medium if CPU >80% sustained or connections >90
#
# File: /Repos/gameplatform-shared-infrastructure/environments/stg/postgres.tfvars

environment = "stg"
vpc_name    = "project-stg-vpc"
region      = "us-east-1"

# Database configuration
postgres_version = "14.17"
instance_class   = "db.t3.small" # CHANGED: Was db.t3.medium (4 GB → 2 GB RAM)
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
max_connections            = "100" # CHANGED: Was 200, reduced for smaller instance
shared_preload_libraries   = "pg_stat_statements,pg_hint_plan"

# Backup configuration - Staging settings
backup_retention_period  = 7 # 7 days retention
backup_window            = "03:00-04:00"
copy_tags_to_snapshot    = true
delete_automated_backups = false

# Maintenance configuration
maintenance_window         = "sun:04:00-sun:06:00"
auto_minor_version_upgrade = true

# Monitoring configuration - KEEP ENABLED for close monitoring
monitoring_interval                   = 60   # NO CHANGE - Keep enhanced monitoring
performance_insights_enabled          = true # NO CHANGE - Keep for monitoring
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
  optimization_plan  = "option-a-conservative"
}

# Scheduler configuration (automated start/stop)
enable_scheduler = false # Set to true to enable automated shutdown/startup
