# -----------------------------------------------------------------------------
# REDIS INSTANCE OUTPUTS
# -----------------------------------------------------------------------------

output "instance_id" {
  description = "Redis instance ID"
  value       = google_redis_instance.main.id
}

output "instance_name" {
  description = "Redis instance name"
  value       = google_redis_instance.main.name
}

output "host" {
  description = "Redis instance host IP"
  value       = google_redis_instance.main.host
}

output "port" {
  description = "Redis instance port"
  value       = google_redis_instance.main.port
}

output "current_location_id" {
  description = "Current zone where Redis is located"
  value       = google_redis_instance.main.current_location_id
}

output "redis_version" {
  description = "Redis version"
  value       = google_redis_instance.main.redis_version
}

# -----------------------------------------------------------------------------
# SECRET OUTPUTS
# -----------------------------------------------------------------------------

output "host_secret_id" {
  description = "Secret Manager secret ID for Redis host"
  value       = module.redis_host_secret.id
}

output "port_secret_id" {
  description = "Secret Manager secret ID for Redis port"
  value       = module.redis_port_secret.id
}

output "connection_secret_id" {
  description = "Secret Manager secret ID for Redis connection string"
  value       = module.redis_connection_secret.id
}

# -----------------------------------------------------------------------------
# CONNECTION INFO
# -----------------------------------------------------------------------------

output "connection_string" {
  description = "Redis connection string"
  value       = "redis://${google_redis_instance.main.host}:${google_redis_instance.main.port}"
  sensitive   = true
}
