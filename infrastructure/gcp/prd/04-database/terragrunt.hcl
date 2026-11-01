# =============================================================================
# 04-DATABASE STACK - PRD ENVIRONMENT
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

  # instance_name defaults to project-prd-postgres (from module)
  database_version = "POSTGRES_15"
  tier             = "db-custom-4-16384" # 4 vCPU, 16GB RAM - equivalent to AWS db.t3.xlarge

  disk_size             = 100
  disk_type             = "PD_SSD"
  disk_autoresize       = true
  disk_autoresize_limit = 500

  # High Availability - equivalent to AWS multi_az = true
  availability_type = "REGIONAL"

  vpc_self_link                      = dependency.networking.outputs.vpc_self_link
  private_service_connection_peering = dependency.networking.outputs.private_service_connection_peering

  databases = {
    nakama = {
      charset   = "UTF8"
      collation = "en_US.UTF-8"  # Match existing database collation
    }
    lobby = {
      charset   = "UTF8"
      collation = "en_US.UTF8"
    }
  }

  users = {
    nakama = {
      password = null
      type     = "BUILT_IN"
    }
    lobby = {
      password = null
      type     = "BUILT_IN"
    }
  }

  # Backup Configuration
  backup_enabled                 = true
  backup_start_time              = "03:00"
  point_in_time_recovery_enabled = true
  transaction_log_retention_days = 7
  retained_backups               = 14

  # Maintenance Window - 3 AM UTC on Sunday
  maintenance_window_day          = 7
  maintenance_window_hour         = 3
  maintenance_window_update_track = "stable"

  # Database Flags - increased max_connections for high traffic
  database_flags = [
    {
      name  = "max_connections"
      value = "5000"
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
    }
  ]

  # Query Insights - equivalent to AWS performance_insights_enabled
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
    managed_by  = "terragrunt"
  }
}
