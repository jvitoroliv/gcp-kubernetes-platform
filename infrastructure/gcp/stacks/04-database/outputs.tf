# -----------------------------------------------------------------------------
# CLOUD SQL INSTANCE OUTPUTS
# -----------------------------------------------------------------------------

output "instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.main.name
}

output "instance_connection_name" {
  description = "Cloud SQL instance connection name (for Cloud SQL Proxy)"
  value       = google_sql_database_instance.main.connection_name
}

output "instance_private_ip" {
  description = "Private IP address of the Cloud SQL instance"
  value       = google_sql_database_instance.main.private_ip_address
}

output "instance_self_link" {
  description = "Cloud SQL instance self link"
  value       = google_sql_database_instance.main.self_link
}

# -----------------------------------------------------------------------------
# DATABASE OUTPUTS
# -----------------------------------------------------------------------------

output "databases" {
  description = "Map of created databases"
  value = {
    for key, db in google_sql_database.databases : key => {
      name    = db.name
      charset = db.charset
    }
  }
}

# -----------------------------------------------------------------------------
# USER OUTPUTS
# -----------------------------------------------------------------------------

output "users" {
  description = "Map of created database users (without passwords)"
  value = {
    for key, user in google_sql_user.users : key => {
      name = user.name
      type = user.type
    }
  }
}

# -----------------------------------------------------------------------------
# SECRET MANAGER OUTPUTS
# -----------------------------------------------------------------------------

output "connection_secret_ids" {
  description = "Map of database connection string secret IDs"
  value = {
    for key, secret in module.db_connection_secrets : key => secret.id
  }
}

output "password_secret_ids" {
  description = "Map of database password secret IDs"
  value = {
    for key, secret in module.db_password_secrets : key => secret.id
  }
}

output "host_secret_id" {
  description = "Database host secret ID"
  value       = module.db_host_secret.id
}

# -----------------------------------------------------------------------------
# CONNECTION INFORMATION
# -----------------------------------------------------------------------------

output "connection_info" {
  description = "Connection information for applications"
  value = {
    host              = google_sql_database_instance.main.private_ip_address
    port              = 5432
    connection_name   = google_sql_database_instance.main.connection_name
    database_version  = var.database_version
    availability_type = var.availability_type
  }
  sensitive = true
}
