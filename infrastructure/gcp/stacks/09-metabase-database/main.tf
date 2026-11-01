# -----------------------------------------------------------------------------
# METABASE DATABASE STACK
# This stack sets up an ISOLATED Cloud SQL PostgreSQL instance for Metabase:
# - Dedicated Cloud SQL instance (separate from main project-prd-postgres)
# - Database and user for Metabase
# - Secrets stored in Secret Manager
# -----------------------------------------------------------------------------

locals {
  common_labels = merge({
    project     = "gameplatform"
    environment = var.environment
    component   = "metabase-database"
    managed_by  = "terraform"
  }, var.labels)

  # Naming convention
  name_prefix   = "gameplatform-${var.environment}"
  instance_name = var.instance_name != "" ? var.instance_name : "${local.name_prefix}-metabase-postgres"
}

# -----------------------------------------------------------------------------
# CLOUD SQL INSTANCE (Dedicated for Metabase)
# -----------------------------------------------------------------------------

resource "google_sql_database_instance" "metabase" {
  name                = local.instance_name
  project             = var.project_id
  region              = var.region
  database_version    = var.database_version
  deletion_protection = var.deletion_protection

  settings {
    edition           = var.edition
    tier              = var.tier
    availability_type = var.availability_type
    disk_size         = var.disk_size
    disk_type         = var.disk_type
    disk_autoresize       = var.disk_autoresize
    disk_autoresize_limit = var.disk_autoresize_limit

    # Private IP configuration
    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.vpc_self_link
      enable_private_path_for_google_cloud_services = true
    }

    # Backup configuration
    backup_configuration {
      enabled                        = var.backup_enabled
      start_time                     = var.backup_start_time
      location                       = var.backup_location != "" ? var.backup_location : var.region
      point_in_time_recovery_enabled = var.point_in_time_recovery_enabled
      transaction_log_retention_days = var.transaction_log_retention_days

      backup_retention_settings {
        retained_backups = var.retained_backups
        retention_unit   = "COUNT"
      }
    }

    # Maintenance window
    maintenance_window {
      day          = var.maintenance_window_day
      hour         = var.maintenance_window_hour
      update_track = var.maintenance_window_update_track
    }

    # Database flags
    dynamic "database_flags" {
      for_each = var.database_flags
      content {
        name  = database_flags.value.name
        value = database_flags.value.value
      }
    }

    # Query insights
    insights_config {
      query_insights_enabled  = var.insights_config.query_insights_enabled
      query_string_length     = var.insights_config.query_string_length
      record_application_tags = var.insights_config.record_application_tags
      record_client_address   = var.insights_config.record_client_address
    }

    user_labels = local.common_labels
  }

  # Ensure private service connection exists
  depends_on = [var.private_service_connection_peering]
}

# -----------------------------------------------------------------------------
# DATABASE
# -----------------------------------------------------------------------------

resource "google_sql_database" "metabase" {
  name      = "metabase"
  project   = var.project_id
  instance  = google_sql_database_instance.metabase.name
  charset   = "UTF8"
  collation = "en_US.UTF8"

  depends_on = [google_sql_database_instance.metabase]
}

# -----------------------------------------------------------------------------
# DATABASE USER
# Generate random password and create user
# -----------------------------------------------------------------------------

resource "random_password" "metabase_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "google_sql_user" "metabase" {
  name     = "metabase"
  project  = var.project_id
  instance = google_sql_database_instance.metabase.name
  type     = "BUILT_IN"
  password = random_password.metabase_password.result

  depends_on = [google_sql_database_instance.metabase]
}

# -----------------------------------------------------------------------------
# SECRET MANAGER - Store database credentials
# -----------------------------------------------------------------------------

# Database connection string secret
module "metabase_connection_secret" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/secret-manager-secret"

  secret_id = "${local.name_prefix}-metabase-db-connection"
  project   = var.project_id

  labels = merge(local.common_labels, {
    database = "metabase"
    type     = "connection-string"
  })
}

module "metabase_connection_version" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/secret-manager-secret-version"

  secret      = module.metabase_connection_secret.id
  secret_data = "postgresql://metabase:${urlencode(google_sql_user.metabase.password)}@${google_sql_database_instance.metabase.private_ip_address}:5432/metabase?sslmode=disable"

  depends_on = [module.metabase_connection_secret, google_sql_user.metabase]
}

# Password secret
module "metabase_password_secret" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/secret-manager-secret"

  secret_id = "${local.name_prefix}-metabase-db-password"
  project   = var.project_id

  labels = merge(local.common_labels, {
    database = "metabase"
    type     = "password"
  })
}

module "metabase_password_version" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/secret-manager-secret-version"

  secret      = module.metabase_password_secret.id
  secret_data = google_sql_user.metabase.password

  depends_on = [module.metabase_password_secret, google_sql_user.metabase]
}

# Database host secret
module "metabase_host_secret" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/secret-manager-secret"

  secret_id = "${local.name_prefix}-metabase-db-host"
  project   = var.project_id

  labels = merge(local.common_labels, {
    database = "metabase"
    type     = "host"
  })
}

module "metabase_host_version" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/secret-manager-secret-version"

  secret      = module.metabase_host_secret.id
  secret_data = google_sql_database_instance.metabase.private_ip_address

  depends_on = [module.metabase_host_secret, google_sql_database_instance.metabase]
}
