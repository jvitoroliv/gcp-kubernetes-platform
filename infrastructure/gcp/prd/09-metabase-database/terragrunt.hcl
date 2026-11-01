# =============================================================================
# 09-METABASE-DATABASE STACK - PRD ENVIRONMENT
# =============================================================================
# Dedicated Cloud SQL instance for Metabase (isolated from main database)
# Migrating from AWS Aurora Serverless v2 (project-live-metabase-serverless)

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path   = "${get_terragrunt_dir()}/../env.hcl"
  expose = true
}

terraform {
  source = "${get_repo_root()}/stacks/09-metabase-database"
}

dependency "networking" {
  config_path = "../02-networking"

  mock_outputs = {
    vpc_self_link                      = "projects/project-prd-env/global/networks/project-prd-vpc"
    private_service_connection_peering = "servicenetworking-googleapis-com"
  }
}

inputs = {
  project_id  = include.env.locals.project_id
  environment = include.env.locals.environment
  region      = include.env.locals.region

  # Instance Configuration
  # AWS Aurora Serverless v2 (1-64 ACUs) -> GCP db-custom-1-3840 (1 vCPU, 3.75GB)
  # Metabase database is ~100MB, this is more than sufficient
  database_version = "POSTGRES_16" # Same as AWS (16.8)
  tier             = "db-custom-1-3840"

  disk_size             = 20  # 20GB initial (plenty for ~100MB)
  disk_type             = "PD_SSD"
  disk_autoresize       = true
  disk_autoresize_limit = 100

  # ZONAL - Metabase is stateless, data can be restored from backup
  availability_type = "ZONAL"

  vpc_self_link                      = dependency.networking.outputs.vpc_self_link
  private_service_connection_peering = dependency.networking.outputs.private_service_connection_peering

  # Backup Configuration
  backup_enabled                 = true
  backup_start_time              = "04:00" # 4 AM UTC (1 AM BRT)
  point_in_time_recovery_enabled = false   # Not critical for Metabase
  transaction_log_retention_days = 7
  retained_backups               = 7

  # Maintenance Window - 4 AM UTC on Sunday
  maintenance_window_day          = 7
  maintenance_window_hour         = 4
  maintenance_window_update_track = "stable"

  # Database Flags - lighter config for Metabase
  database_flags = [
    {
      name  = "max_connections"
      value = "100"
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
    }
  ]

  # Query Insights
  insights_config = {
    query_insights_enabled  = true
    query_string_length     = 1024
    record_application_tags = true
    record_client_address   = true
  }

  # Deletion Protection
  deletion_protection = true

  labels = {
    environment = "prd"
    project     = "gameplatform"
    component   = "metabase"
    managed_by  = "terragrunt"
  }
}
