# =============================================================================
# STG ENVIRONMENT - DATABASE STACK
# NOTE: Stg has SAME configuration as Prd for parity testing
# =============================================================================

project_id  = "project-nonprod-env"
environment = "stg"
region      = "us-east1"

# Network references (from 02-networking outputs)
# vpc_self_link                      = "projects/project-nonprod-env/global/networks/project-nonprod-env-vpc"
# private_service_connection_peering = "servicenetworking-googleapis-com"

# Cloud SQL Instance Configuration - SAME AS PRD
database_version      = "POSTGRES_15"
tier                  = "db-custom-4-16384" # 4 vCPUs, 16GB RAM - SAME AS PRD
disk_size             = 100
disk_type             = "PD_SSD"
disk_autoresize       = true
disk_autoresize_limit = 500

# High Availability - SAME AS PRD
availability_type = "REGIONAL" # HA enabled for staging

# Backup Configuration - SAME AS PRD
backup_enabled                 = true
backup_start_time              = "03:00"
point_in_time_recovery_enabled = true
transaction_log_retention_days = 7
retained_backups               = 14

# Maintenance Window - 3 AM UTC on Sunday
maintenance_window_day          = 7
maintenance_window_hour         = 3
maintenance_window_update_track = "stable"

# Databases
databases = {
  nakama = {
    charset   = "UTF8"
    collation = "en_US.UTF8"
  }
  lobby = {
    charset   = "UTF8"
    collation = "en_US.UTF8"
  }
}

# Database Users
users = {
  nakama = {}
  lobby  = {}
}

# Database Flags - SAME AS PRD
database_flags = [
  {
    name  = "max_connections"
    value = "500"
  },
  {
    name  = "log_checkpoints"
    value = "on"
  },
  {
    name  = "log_connections"
    value = "on"
  },
  {
    name  = "log_disconnections"
    value = "on"
  },
  {
    name  = "log_lock_waits"
    value = "on"
  },
  {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }
]

# Query Insights
insights_config = {
  query_insights_enabled  = true
  query_string_length     = 1024
  record_application_tags = true
  record_client_address   = true
}

# Deletion Protection - SAME AS PRD
deletion_protection = true

labels = {
  owner       = "infrastructure-team"
  cost_center = "stg"
}
