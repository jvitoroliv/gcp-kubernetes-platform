output "service_name" {
  description = "Name of the Cloud Run service"
  value       = module.cloud_run.name
}

output "service_id" {
  description = "ID of the Cloud Run service"
  value       = module.cloud_run.id
}

output "service_uri" {
  description = "URI of the Cloud Run service"
  value       = module.cloud_run.uri
}

output "latest_ready_revision" {
  description = "Latest ready revision"
  value       = module.cloud_run.latest_ready_revision
}
