# -----------------------------------------------------------------------------
# DATABASE STACK
# This stack sets up Cloud SQL PostgreSQL:
# - Cloud SQL instance with private IP
# - Databases for Nakama and Lobby
# - Database users with auto-generated passwords
# - Secrets stored in Secret Manager
# -----------------------------------------------------------------------------

locals {
  common_labels = merge({
    project     = "gameplatform"
    environment = var.environment
    component   = "database"
    managed_by  = "terraform"
  }, var.labels)

  # Naming convention
  name_prefix   = "gameplatform-${var.environment}"
  instance_name = var.instance_name != "" ? var.instance_name : "${local.name_prefix}-postgres"
}

# -----------------------------------------------------------------------------
# CLOUD SQL INSTANCE
# -----------------------------------------------------------------------------

resource "google_sql_database_instance" "main" {
  name                = local.instance_name
  project             = var.project_id
  region              = var.region
  database_version    = var.database_version
  deletion_protection = var.deletion_protection

  settings {
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
# DATABASES
# -----------------------------------------------------------------------------

resource "google_sql_database" "databases" {
  for_each = var.databases

  name      = each.key
  project   = var.project_id
  instance  = google_sql_database_instance.main.name
  charset   = each.value.charset
  collation = each.value.collation

  depends_on = [google_sql_database_instance.main]
}

# -----------------------------------------------------------------------------
# DATABASE USERS
# Generate random passwords and create users
# -----------------------------------------------------------------------------

resource "random_password" "user_passwords" {
  for_each = { for k, v in var.users : k => v if v.password == null }

  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "google_sql_user" "users" {
  for_each = var.users

  name     = each.key
  project  = var.project_id
  instance = google_sql_database_instance.main.name
  type     = each.value.type
  password = each.value.password != null ? each.value.password : random_password.user_passwords[each.key].result

  depends_on = [google_sql_database_instance.main]
}

# -----------------------------------------------------------------------------
# SECRET MANAGER - Store database credentials
# -----------------------------------------------------------------------------

# Database connection string secrets
module "db_connection_secrets" {
  source   = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/secret-manager-secret"
  for_each = var.users

  secret_id = "${local.name_prefix}-db-${each.key}-connection"
  project   = var.project_id

  labels = merge(local.common_labels, {
    database = each.key
    type     = "connection-string"
  })
}

module "db_connection_versions" {
  source   = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/secret-manager-secret-version"
  for_each = var.users

  secret      = module.db_connection_secrets[each.key].id
  secret_data = "postgresql://${each.key}:${urlencode(google_sql_user.users[each.key].password)}@${google_sql_database_instance.main.private_ip_address}:5432/${each.key}?sslmode=disable"

  depends_on = [module.db_connection_secrets, google_sql_user.users]
}

# Individual password secrets
module "db_password_secrets" {
  source   = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/secret-manager-secret"
  for_each = var.users

  secret_id = "${local.name_prefix}-db-${each.key}-password"
  project   = var.project_id

  labels = merge(local.common_labels, {
    database = each.key
    type     = "password"
  })
}

module "db_password_versions" {
  source   = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/secret-manager-secret-version"
  for_each = var.users

  secret      = module.db_password_secrets[each.key].id
  secret_data = google_sql_user.users[each.key].password

  depends_on = [module.db_password_secrets, google_sql_user.users]
}

# Database host secret
module "db_host_secret" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/secret-manager-secret"

  secret_id = "${local.name_prefix}-db-host"
  project   = var.project_id

  labels = merge(local.common_labels, {
    type = "host"
  })
}

module "db_host_version" {
  source = "git::https://github.com/example-gamedev-org/gameplatform-terraform.git//modules/gcp/secret-manager-secret-version"

  secret      = module.db_host_secret.id
  secret_data = google_sql_database_instance.main.private_ip_address

  depends_on = [module.db_host_secret, google_sql_database_instance.main]
}
