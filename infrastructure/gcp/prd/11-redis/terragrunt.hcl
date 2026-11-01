# =============================================================================
# 11-REDIS STACK - PRD ENVIRONMENT
# =============================================================================
# Memorystore Redis for session/cache management
# Used by lobby-backend for login code verification

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path   = "${get_terragrunt_dir()}/../env.hcl"
  expose = true
}

terraform {
  source = "${get_repo_root()}/stacks/11-redis"
}

dependency "networking" {
  config_path = "../02-networking"

  mock_outputs = {
    vpc_id                             = "projects/project-prd-env/global/networks/project-prd-vpc"
    private_service_connection_peering = "servicenetworking-googleapis-com"
  }
}

inputs = {
  project_id  = include.env.locals.project_id
  environment = include.env.locals.environment
  region      = include.env.locals.region

  # Redis Configuration
  # BASIC tier is sufficient for login codes (non-critical, can regenerate)
  # Use STANDARD_HA if you need high availability
  tier           = "BASIC"
  memory_size_gb = 1
  redis_version  = "REDIS_7_0"

  # Network
  vpc_id                             = dependency.networking.outputs.vpc_id
  private_service_connection_peering = dependency.networking.outputs.private_service_connection_peering

  # Redis settings
  redis_configs = {
    maxmemory-policy = "allkeys-lru" # Evict least recently used keys when memory is full
  }

  # Maintenance Window - 3 AM UTC on Sunday
  maintenance_window_day  = "SUNDAY"
  maintenance_window_hour = 3

  labels = {
    environment = "prd"
    project     = "gameplatform"
    managed_by  = "terragrunt"
    component   = "cache"
  }
}
