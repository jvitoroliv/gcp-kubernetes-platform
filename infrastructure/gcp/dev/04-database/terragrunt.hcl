# =============================================================================
# 04-DATABASE STACK - DEV ENVIRONMENT
# =============================================================================

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path   = "${get_terragrunt_dir()}/../env.hcl"
  expose = true
}

terraform {
  source = "${get_repo_root()}/stacks/04-database"
}

dependency "networking" {
  config_path = "../../nonprod/02-networking"

  mock_outputs = {
    vpc_self_link                      = "projects/project-nonprod-env/global/networks/gameplatform-nonprod-vpc"
    private_service_connection_peering = "servicenetworking-googleapis-com"
  }
}

inputs = {
  project_id  = include.env.locals.project_id
  environment = include.env.locals.environment
  region      = include.env.locals.region

  # Network references (from 02-networking outputs)
  vpc_self_link                      = dependency.networking.outputs.vpc_self_link
  private_service_connection_peering = dependency.networking.outputs.private_service_connection_peering

  # Cloud SQL Instance Configuration
  database_version      = "POSTGRES_15"
  tier                  = "db-custom-1-3840" # 1 vCPU, 3.75GB RAM - small for dev
  disk_size             = 20
  disk_type             = "PD_SSD"
  disk_autoresize       = true
  disk_autoresize_limit = 100

  # High Availability - Disabled for dev
  availability_type = "ZONAL"

  # Backup Configuration - Minimal for dev
  backup_enabled                 = true
  backup_start_time              = "03:00"
  point_in_time_recovery_enabled = false
  transaction_log_retention_days = 1
  retained_backups               = 3

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

  # Database Flags - Fewer connections for dev
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
    }
  ]

  # Query Insights
  insights_config = {
    query_insights_enabled  = true
    query_string_length     = 1024
    record_application_tags = true
    record_client_address   = true
  }

  # Deletion Protection - Disabled for dev
  deletion_protection = false

  labels = {
    environment = "dev"
    project     = "gameplatform"
    managed_by  = "terragrunt"
    owner       = "infrastructure-team"
    cost_center = "development"
  }
}
