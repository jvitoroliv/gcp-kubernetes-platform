# Production values for Metabase database (RDS Aurora Serverless v2)
environment = "live"
region      = "sa-east-1"

# Aurora Serverless Configuration
engine_version    = "16.6"
database_name     = "metabase"
master_username   = "postgres"
database_password = "" # Leave empty to generate random password

# Serverless Capacity Configuration (ACUs)
serverless_min_capacity = 1  # Minimum 1 ACU
serverless_max_capacity = 64 # Maximum 64 ACUs

# Instance Configuration
instance_count = 1 # Single writer instance

# Backup Configuration
backup_retention_period      = 7
preferred_backup_window      = "03:00-04:00"
preferred_maintenance_window = "sun:04:00-sun:05:00"

# Protection Settings
skip_final_snapshot         = false
deletion_protection         = true
apply_immediately           = false
allow_major_version_upgrade = false

# Performance and Monitoring
performance_insights_enabled = true
monitoring_interval          = 0

# CloudWatch Configuration
log_retention_days = 30

# Alarm Thresholds
cpu_alarm_threshold         = 80
connections_alarm_threshold = 80
capacity_alarm_threshold    = 50

rds-security-group-name = "live-postgres-postgres-sg"

# Production Tags
additional_tags = {
  DataClassification = "sensitive"
  Compliance         = "required"
  DisasterRecovery   = "tier1"
  CostCenter         = "engineering"
  Owner              = "devops"
  Backup             = "continuous"
  MonitoringTier     = "critical"
  DatabaseType       = "serverless"
  Application        = "metabase"
}