# -----------------------------------------------------------------------------
# CLOUD SQL INSTANCE OUTPUTS
# -----------------------------------------------------------------------------

output "instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.metabase.name
}

output "instance_connection_name" {
  description = "Cloud SQL instance connection name (for Cloud SQL Proxy)"
  value       = google_sql_database_instance.metabase.connection_name
}

output "instance_private_ip" {
  description = "Private IP address of the Cloud SQL instance"
  value       = google_sql_database_instance.metabase.private_ip_address
}

output "instance_self_link" {
  description = "Cloud SQL instance self link"
  value       = google_sql_database_instance.metabase.self_link
}

# -----------------------------------------------------------------------------
# DATABASE OUTPUTS
# -----------------------------------------------------------------------------

output "database_name" {
  description = "Metabase database name"
  value       = google_sql_database.metabase.name
}

# -----------------------------------------------------------------------------
# USER OUTPUTS
# -----------------------------------------------------------------------------

output "user_name" {
  description = "Metabase database user name"
  value       = google_sql_user.metabase.name
}

# -----------------------------------------------------------------------------
# SECRET MANAGER OUTPUTS
# -----------------------------------------------------------------------------

output "connection_secret_id" {
  description = "Metabase database connection string secret ID"
  value       = module.metabase_connection_secret.id
}

output "password_secret_id" {
  description = "Metabase database password secret ID"
  value       = module.metabase_password_secret.id
}

output "host_secret_id" {
  description = "Metabase database host secret ID"
  value       = module.metabase_host_secret.id
}

# -----------------------------------------------------------------------------
# CONNECTION INFORMATION
# -----------------------------------------------------------------------------

output "connection_info" {
  description = "Connection information for Metabase"
  value = {
    host              = google_sql_database_instance.metabase.private_ip_address
    port              = 5432
    database          = "metabase"
    user              = "metabase"
    connection_name   = google_sql_database_instance.metabase.connection_name
    database_version  = var.database_version
    availability_type = var.availability_type
  }
  sensitive = true
}
