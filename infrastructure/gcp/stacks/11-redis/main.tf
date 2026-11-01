# -----------------------------------------------------------------------------
# REDIS STACK
# This stack sets up Google Cloud Memorystore Redis:
# - Memorystore Redis instance with private IP
# - Secrets stored in Secret Manager
# -----------------------------------------------------------------------------

locals {
  common_labels = merge({
    project     = "gameplatform"
    environment = var.environment
    component   = "redis"
    managed_by  = "terraform"
  }, var.labels)

  # Naming convention
  name_prefix   = "gameplatform-${var.environment}"
  instance_name = var.instance_name != "" ? var.instance_name : "${local.name_prefix}-redis"
}

# -----------------------------------------------------------------------------
# MEMORYSTORE REDIS INSTANCE
# -----------------------------------------------------------------------------

resource "google_redis_instance" "main" {
  name           = local.instance_name
  project        = var.project_id
  region         = var.region
  tier           = var.tier
  memory_size_gb = var.memory_size_gb

  # Network configuration
  authorized_network = var.vpc_id
  connect_mode       = "PRIVATE_SERVICE_ACCESS"

  # Redis version
  redis_version = var.redis_version
  display_name  = "${local.name_prefix} Redis"

  # Redis configuration
  redis_configs = var.redis_configs

  # Maintenance policy
  dynamic "maintenance_policy" {
    for_each = var.maintenance_window_day != null ? [1] : []
    content {
      weekly_maintenance_window {
        day = var.maintenance_window_day
        start_time {
          hours   = var.maintenance_window_hour
          minutes = 0
          seconds = 0
          nanos   = 0
        }
      }
    }
  }

  labels = local.common_labels

  depends_on = [var.private_service_connection_peering]
}

# -----------------------------------------------------------------------------
# SECRET MANAGER - Store Redis connection details
# -----------------------------------------------------------------------------

# Redis host secret
module "redis_host_secret" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/secret-manager-secret"

  secret_id = "${local.name_prefix}-redis-host"
  project   = var.project_id

  labels = merge(local.common_labels, {
    type = "host"
  })
}

module "redis_host_version" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/secret-manager-secret-version"

  secret      = module.redis_host_secret.id
  secret_data = google_redis_instance.main.host

  depends_on = [module.redis_host_secret, google_redis_instance.main]
}

# Redis port secret
module "redis_port_secret" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/secret-manager-secret"

  secret_id = "${local.name_prefix}-redis-port"
  project   = var.project_id

  labels = merge(local.common_labels, {
    type = "port"
  })
}

module "redis_port_version" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/secret-manager-secret-version"

  secret      = module.redis_port_secret.id
  secret_data = tostring(google_redis_instance.main.port)

  depends_on = [module.redis_port_secret, google_redis_instance.main]
}

# Redis connection string secret (for convenience)
module "redis_connection_secret" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/secret-manager-secret"

  secret_id = "${local.name_prefix}-redis-connection"
  project   = var.project_id

  labels = merge(local.common_labels, {
    type = "connection-string"
  })
}

module "redis_connection_version" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/secret-manager-secret-version"

  secret      = module.redis_connection_secret.id
  secret_data = "redis://${google_redis_instance.main.host}:${google_redis_instance.main.port}"

  depends_on = [module.redis_connection_secret, google_redis_instance.main]
}
